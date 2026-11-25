# PDF Pipeline Architecture

This document describes the proposed architecture for [PDF Pipeline](../README.md). The first deployment will run locally against Floci. An AWS deployment is an optional milestone. The [system requirements](./system-requirements.md) define the API, interface, and acceptance targets.

![Target AWS architecture for PDF Pipeline](./Architecture.drawio.svg)

## Components

| Component | Responsibility |
| --- | --- |
| Web GUI | Uses HTML, CSS, Bootstrap, and vanilla JavaScript to provide upload progress, status polling, results, downloads, deletion, and authorized retry through the REST API. |
| VPC, ALB, and EC2 Auto Scaling group | Span two Availability Zones. The public ALB routes traffic to healthy EC2 instances in private application subnets. |
| REST API | Serves the GUI assets, validates uploads, manages documents, enforces administrative authorization, and exposes `/health`. The application is stateless. |
| S3 | Stores original PDFs and processing results in separate private buckets. The API mediates user access to both. |
| DynamoDB | Stores document metadata, processing state, timestamps, failure reasons, and references to S3 objects. |
| EventBridge | Routes `Object Created` events from the S3 input bucket to the processing queue. |
| SQS and dead-letter queue | Buffer work, support redelivery after transient failures, and retain messages that exhaust delivery attempts for inspection. |
| Lambda | Reads originals, extracts text and metadata, counts words and characters, writes results, and updates document state. Worker capacity scales separately from the API. |
| Failure reconciliation | Uses dead-letter queue messages to record terminal processing failures in DynamoDB. |
| CloudWatch | Collects structured logs and metrics, supports dashboards, and raises alarms on configured thresholds. |

## Request and processing flow

![Event-driven document-processing workflow](./document-processing-workflow.svg)

1. A client uploads a PDF to `POST /api/documents`. The API validates the file contents and enforces the 10 MB and 100-page limits.
2. The API assigns a document ID, creates the DynamoDB record in `UPLOADED`, and writes the original to its S3 input key. Creating the record first lets the worker resolve the document even if the event arrives before the HTTP response. The API returns HTTP `202 Accepted` with processing still asynchronous once both writes succeed.
3. The input bucket emits an `Object Created` event. An EventBridge rule routes it to the SQS processing queue, whose event source mapping invokes Lambda. The processor uses the input key to resolve the document and its initial processing version. It claims that version in DynamoDB before reading the PDF.
4. The worker extracts text, page count, file size, and embedded title and author when available. It calculates word and character counts, writes the result to the S3 output bucket, and conditionally records the metadata, result reference, and completion timestamp in DynamoDB.
5. The GUI polls the API for status. Clients retrieve metadata and download the original or results using the documented REST endpoints. A result becomes available after the worker records `COMPLETED` and its result reference.

Processing covers embedded text, PDF metadata, and document statistics. OCR for scanned pages, AI summarization, editing, and format conversion are outside the initial scope.

## State, retries, and deletion

The [document lifecycle diagram](./diagram.png) shows the processing states. `UPLOADED` is the initial document state. `QUEUED`, if implemented, indicates dispatch to the processing queue. `PROCESSING` indicates a worker claim. `RETRYING` indicates a transient error pending redelivery. `COMPLETED` indicates a stored result. `FAILED` records a permanent error or exhausted delivery attempts. DynamoDB is authoritative for the current state.

- **Duplicate delivery and worker recovery.** Use conditional DynamoDB writes and processing versions to handle duplicate, delayed, and out-of-order messages. A redelivered message can reclaim an expired worker claim. Use deterministic result keys scoped to the processing version and claim so a stale worker cannot overwrite a committed result or advance state.
- **Failure handling.** Use a baseline of three processing attempts, a 60-second Lambda timeout, a 360-second SQS visibility timeout, and four-day processing queue retention. Report transient failures per message so SQS can retry them independently. Record permanent failures in DynamoDB and acknowledge their messages. When SQS moves an exhausted job to the dead-letter queue, reconcile its active processing version to `FAILED` and make failure details available for administrative inspection.
- **Administrative retry.** `POST /api/documents/{id}/retry` checks administrator authorization and confirms the document is `FAILED`. The API prepares a new processing version and sends the job directly to the processing queue. The job reuses the original PDF. Earlier versions cannot update the current result or state.
- **Deletion.** Allow deletion in terminal states (`COMPLETED` and `FAILED`). Coordinate deletion and manual retry through conditional state checks. Remove the original, any results, and the metadata, and make cleanup safe to retry after a partial failure.

Implementation must define recovery for partial uploads and for a manual retry whose DynamoDB update succeeds but whose SQS send fails.

## DynamoDB document record

![DynamoDB document record ERD showing the embedded maps and sparse listing index](./document-record-erd.svg)

The proposed `documents` table stores one item per document. Its partition key is `documentId` (string), with no sort key. API reads, processing claims, failure reconciliation, and administrative updates all address the same item. The original PDF and extracted text reside in S3.

| Attribute | DynamoDB type | Meaning |
| --- | --- | --- |
| `documentId` | String | Immutable application-generated ID. The input key `originals/{documentId}.pdf` lets the upload event resolve the item directly. |
| `originalFilename`, `fileSizeBytes` | String, Number | Validated upload metadata. The filename is display metadata. |
| `originalKey`, `resultKey` | String | Keys in the configured input and output buckets, respectively. `resultKey` appears when the result is committed. |
| `status`, `processingVersion` | String, Number | Document lifecycle state and active processing version. The initial version is `1`. An administrative retry increments it. |
| `createdAt`, `uploadedAt` | String | Record creation and successful upload timestamps. Set `uploadedAt` after the S3 write succeeds. |
| `processingStartedAt`, `processingEndedAt` | String | First claim and terminal outcome for the active version. Automatic retries preserve the first start time. |
| `claimId`, `claimExpiresAt` | String, Number | Worker claim token and lease expiry as Unix epoch seconds. Present while a claim is active. |
| `metadata` | Map | `pageCount`, `wordCount`, and `characterCount` as numbers, with `title` and `author` as strings when available. |
| `failure` | Map | Stable `code`, sanitized `message`, `kind` (`PERMANENT` or `RETRIES_EXHAUSTED`), and `recordedAt`. Present on terminal failure. |
| `retryDispatchPending`, `deletionRequestedAt` | Boolean, String | Internal markers for an unconfirmed retry submission and in-progress deletion. |
| `listPartition`, `listSort` | String | Sparse index keys, set once upload succeeds and removed when deletion starts. |

Use fixed-width UTC timestamps such as `2026-11-26T12:30:00.000Z` for date strings and omit optional attributes until they apply.

### Access patterns

- **Document details, status, and downloads.** Use a strongly consistent `GetItem` when the caller needs the current record. Serve the original after upload succeeds and the result when `status = COMPLETED` and `resultKey` exists. Exclude items marked for deletion.
- **Document list.** Query the sparse `DocumentsByUploadTime` global secondary index with `listPartition = DOCUMENTS` and `listSort = {uploadedAt}#{documentId}`. Read newest first, project `originalFilename`, `uploadedAt`, and `status`, and paginate with `LastEvaluatedKey`. The dashboard can briefly show stale entries or status because index reads are eventually consistent. The shared partition key keeps the initial list query simple and concentrates index traffic on one key, so reassess it if load testing shows throttling. [DynamoDB global secondary indexes](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/GSI.html) · [DynamoDB Query](https://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_Query.html)

### Conditional writes

| Operation | Condition and update |
| --- | --- |
| Accept upload | Create the record only if the ID is unused. After the S3 write, set `uploadedAt` and the listing keys without changing `status`. An early event can advance processing before this update. |
| Claim job | An S3 event targets version `1`. An administrative retry message carries its version explicitly. Require an existing item, the expected version, no deletion marker, and an eligible state (`UPLOADED`, `QUEUED`, `RETRYING`, or `PROCESSING` with an expired lease). Set `PROCESSING`, initialize `processingStartedAt` if absent, and issue a fresh claim token and lease. |
| Finish or release claim | Require `PROCESSING`, the matching version and claim token, an unexpired lease, and no deletion marker. On success, write the result to `results/{documentId}/{processingVersion}/{claimId}.json` first, then commit `resultKey`, `metadata`, `processingEndedAt`, and `COMPLETED` together. On transient failure, set `RETRYING`. On permanent failure, set `FAILED` with failure details and `processingEndedAt`. Clear the claim attributes when releasing it. |
| Reconcile exhausted job | Require the matching version, a nonterminal state, and no unexpired claim or deletion marker. Set `FAILED`, record the failure and end time, and clear claim attributes. Ignore obsolete or already-terminal jobs. Revisit a matching job if its claim is still active. |
| Prepare administrative retry | Require an accepted upload in `FAILED` with no deletion marker. Increment `processingVersion`, set `RETRYING`, clear the previous version's claim, result, metadata, timestamps, and failure, and set `retryDispatchPending`. Clear the marker for that version after a successful SQS send or worker claim. A pending marker allows recovery to resend that same version. |
| Delete document | Require `COMPLETED` or `FAILED`. Set `deletionRequestedAt` and remove the list index keys in the same update. This blocks retry and worker state changes while the API removes S3 objects under the document's keys and prefixes. Account for writes from workers that lost their claims before cleanup completes. Remove the record after cleanup succeeds. |

## Deployment and security

**Local.** Run the application against Floci using configurable AWS endpoints and AWS-compatible SDKs. Use Terraform to provision supported integrations and keep environment-specific settings outside business logic.

**AWS.** Place the ALB in public subnets across two Availability Zones and serve production client traffic over HTTPS. Run the GUI and REST API on stateless EC2 instances in private application subnets across both zones. The ALB checks `/health` and routes traffic to healthy targets. Reusable Terraform modules provision the network, application infrastructure, storage, event routing, workers, and monitoring.

Use least-privilege roles for the EC2 application, Lambda processor, and failure reconciliation. Block public access to S3 and encrypt production document and result storage at rest. Keep credentials outside source control and out of the browser. Validate uploads as untrusted input, bound parser resource use, and enforce administrative authorization in the API.

## Observability and validation

- Include the document ID in structured logs across ingestion, publication, processing, and retries. Record state transitions and durations without logging credentials or extracted text.
- Monitor request counts and error rates, queue depth and age, processing duration, and DLQ activity. Configure CloudWatch dashboards and alarms for operational thresholds.
- Use GitHub Actions for application tests, builds, and deployment validation for the API and worker, along with Terraform formatting and validation. Exercise the API and GUI workflows, input bucket event routing, duplicate delivery, worker failure, and retry exhaustion in Floci where supported. Verify emulator support for each integration before relying on it.
- Measure the proposed latency, throughput, and concurrency targets under load. Validate multi-AZ failover, scaling, IAM enforcement, encryption, and performance in AWS if deployed.
