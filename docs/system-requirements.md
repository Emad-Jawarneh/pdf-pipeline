# PDF Pipeline — System Requirements

### 1. System overview

PDF Pipeline is an event-driven document processing platform designed to demonstrate cloud infrastructure provisioning, asynchronous processing, distributed system reliability, scalability, and observability using AWS services and Terraform.

The system allows users to upload PDF documents through a web-based graphical user interface (GUI) or REST API, automatically processes them through an asynchronous pipeline, and provides access to processing results and document metadata. The GUI acts as a thin presentation layer that consumes the existing REST API.

The entire application will initially operate in a local AWS emulation environment using Floci.

### 2. Functional requirements

#### 2.1. Document management

| ID | Requirement |
| --- | --- |
| FR-01 | The system shall allow users to upload PDF documents through a REST API and web-based GUI. |
| FR-02 | The system shall validate uploaded files for format and size. |
| FR-03 | The system shall assign a unique identifier to each uploaded document. |
| FR-04 | The system shall store original documents in an S3 bucket. |
| FR-05 | The system shall allow users to retrieve original documents. |
| FR-06 | The system shall allow users to retrieve a list of uploaded documents. |
| FR-07 | The system shall allow users to delete documents and their associated processing results. |

#### 2.2. Document processing

| ID | Requirement |
| --- | --- |
| FR-08 | The system shall automatically generate an event when a document is uploaded. |
| FR-09 | The system shall route document upload events through EventBridge to an SQS queue. |
| FR-10 | The system shall process queued documents asynchronously using Lambda functions. |
| FR-11 | The system shall extract textual content from PDF documents. |
| FR-12 | The system shall extract document metadata, including page count, file size, title, and author, where available. |
| FR-13 | The system shall calculate the word and character counts of extracted text. |
| FR-14 | The system shall store processing results in a separate S3 bucket. |
| FR-15 | The system shall store document metadata and processing status in DynamoDB. |
| FR-16 | The system shall support concurrent processing of multiple documents. |

#### 2.3. Processing status and results

| ID | Requirement |
| --- | --- |
| FR-17 | The system shall maintain a processing status for each document. |
| FR-18 | The system shall allow users to retrieve the current processing status through the API. |
| FR-19 | The system shall allow users to retrieve extracted document metadata. |
| FR-20 | The system shall allow users to download processing results. |
| FR-21 | The system shall record document upload, processing start, and processing completion timestamps. |
| FR-22 | The system shall record failure reasons for unsuccessfully processed documents. |

#### 2.4. Failure handling and recovery

| ID | Requirement |
| --- | --- |
| FR-23 | The system shall automatically retry failed processing operations according to a configurable retry policy. |
| FR-24 | The system shall transfer messages that exceed the maximum delivery attempts to a dead-letter queue (DLQ). |
| FR-25 | The system shall prevent duplicate events from producing duplicate processing results. |
| FR-26 | The system shall allow administrators to inspect failed messages. |
| FR-27 | The system shall allow administrators to reprocess failed documents. |
| FR-28 | The system shall distinguish between retryable and permanent processing failures. |

#### 2.5. Monitoring and administration

| ID | Requirement |
| --- | --- |
| FR-29 | The system shall generate logs for API requests and document processing operations. |
| FR-30 | The system shall collect infrastructure and application metrics through CloudWatch. |
| FR-31 | The system shall monitor queue depth, processing duration, error rates, and request counts. |
| FR-32 | The system shall generate alerts when configurable operational thresholds are exceeded. |
| FR-33 | The system shall provide a health-check API endpoint. |
| FR-34 | The system shall associate document processing logs with a unique document identifier. |

#### 2.6. Graphical user interface

| ID | Requirement |
| --- | --- |
| FR-35 | The system shall provide a web-based graphical user interface. |
| FR-36 | The system shall allow users to upload PDF documents through a file selection interface. |
| FR-37 | The system shall display upload progress. |
| FR-38 | The system shall display a list of uploaded documents and their processing statuses. |
| FR-39 | The system shall automatically refresh document processing statuses without requiring a page reload. |
| FR-40 | The system shall display extracted document metadata and processing results. |
| FR-41 | The system shall allow users to download original documents and processing results through the GUI. |
| FR-42 | The system shall allow users to delete documents through the GUI. |
| FR-43 | The system shall display appropriate error and success messages. |
| FR-44 | The system shall allow authorized administrators to reprocess failed documents through the GUI. |

### 3. Non-functional requirements

The following numerical thresholds are proposed acceptance targets, rather than measured or guaranteed system capabilities. They should be adjusted after establishing a performance baseline.

#### 3.1. Performance

| ID | Requirement |
| --- | --- |
| NFR-01 | Metadata and status API requests shall achieve a P95 response time below 500 ms under normal load. |
| NFR-02 | The system shall acknowledge successful uploads without waiting for document processing to complete. |
| NFR-03 | The system shall process text-based PDF documents of up to 10 MB and 100 pages within 30 seconds under normal load. |
| NFR-04 | The system shall support at least 50 concurrent API clients under the defined test workload. |
| NFR-05 | The system shall support at least 100 queued documents without losing processing requests. |

#### 3.2. Scalability

| ID | Requirement |
| --- | --- |
| NFR-06 | The API application shall be stateless to support horizontal scaling. |
| NFR-07 | Incoming API traffic shall be distributed through an Application Load Balancer. |
| NFR-08 | EC2 instances shall scale horizontally according to configurable resource utilization thresholds. |
| NFR-09 | Document processing capacity shall scale independently of the API application. |
| NFR-10 | The messaging layer shall buffer temporary differences between document ingestion and processing capacity. |

#### 3.3. Availability and fault tolerance

| ID | Requirement |
| --- | --- |
| NFR-11 | The production infrastructure shall support deployment across at least two Availability Zones. |
| NFR-12 | The API shall remain operational following the failure of a single EC2 instance, provided sufficient healthy capacity remains. |
| NFR-13 | Accepted processing requests shall survive temporary worker failures within the configured message retention period. |
| NFR-14 | Failed document processing operations shall not interrupt unrelated processing operations. |
| NFR-15 | Processing operations shall be idempotent to accommodate at-least-once message delivery. |
| NFR-16 | The system shall recover from temporary processing service failures without requiring manual resubmission of retained messages. |

#### 3.4. Security

| ID | Requirement |
| --- | --- |
| NFR-17 | AWS services shall operate using least-privilege IAM policies. |
| NFR-18 | S3 buckets shall not permit public access. |
| NFR-19 | Documents and processing results shall be encrypted at rest in the production environment. |
| NFR-20 | External production GUI and API communication shall be encrypted using HTTPS. |
| NFR-21 | EC2 application instances shall not be directly accessible from the public internet in the production architecture. |
| NFR-22 | Credentials and secrets shall not be hardcoded or committed to version control. |
| NFR-23 | Uploaded documents shall be treated as untrusted input. |
| NFR-24 | Administrative operations shall require authorization. |

#### 3.5. Maintainability

| ID | Requirement |
| --- | --- |
| NFR-25 | Infrastructure shall be provisioned using Terraform. |
| NFR-26 | Terraform configurations shall be organized into reusable modules. |
| NFR-27 | Application components shall be loosely coupled and independently maintainable. |
| NFR-28 | Environment-specific settings shall be externalized from application code. |
| NFR-29 | The REST API shall be documented using OpenAPI. |
| NFR-30 | Source code and infrastructure configurations shall be maintained in Git. |
| NFR-31 | Infrastructure deployment and local environment initialization shall be reproducible. |

#### 3.6. Testability and deployment

| ID | Requirement |
| --- | --- |
| NFR-32 | Core application logic shall be covered by automated unit tests. |
| NFR-33 | Interactions between AWS services shall be verified through integration tests. |
| NFR-34 | The system shall undergo load testing to evaluate performance and scalability. |
| NFR-35 | The system shall undergo failure-injection testing to evaluate fault tolerance and recovery. |
| NFR-36 | A GitHub Actions CI/CD pipeline shall automate testing and deployment validation. |
| NFR-37 | Terraform configurations shall pass formatting and validation checks before deployment. |

#### 3.7. Observability

| ID | Requirement |
| --- | --- |
| NFR-38 | Application logs shall use a consistent structured format. |
| NFR-39 | Document processing operations shall be traceable across system components. |
| NFR-40 | Operational metrics shall be accessible through monitoring dashboards. |
| NFR-41 | Critical processing failures shall be detectable through automated monitoring. |
| NFR-42 | Logs shall not expose credentials or extracted document contents. |

#### 3.8. Portability

| ID | Requirement |
| --- | --- |
| NFR-43 | The system shall support local execution using Floci for supported AWS service integrations. |
| NFR-44 | AWS service endpoints shall be configurable without modifying business logic. |
| NFR-45 | The application shall use AWS-compatible SDKs and APIs. |
| NFR-46 | Transitioning from Floci to AWS shall not require modifications to core document processing logic. |

#### 3.9. Usability

| ID | Requirement |
| --- | --- |
| NFR-47 | The graphical interface shall provide consistent navigation and visual elements. |
| NFR-48 | The interface shall clearly distinguish between document processing statuses. |
| NFR-49 | The interface shall provide descriptive feedback for unsuccessful operations. |
| NFR-50 | The interface shall request confirmation before destructive operations. |
| NFR-51 | The interface shall support common desktop screen resolutions. |
| NFR-52 | The interface shall support current versions of major web browsers. |

#### 3.10. Presentation layer architecture

| ID | Requirement |
| --- | --- |
| NFR-53 | The presentation layer shall remain independent of the document processing logic. |
| NFR-54 | The GUI shall communicate with backend services exclusively through the REST API. |
| NFR-55 | Background document processing shall not block user interaction with the interface. |
| NFR-56 | The GUI shall not contain AWS credentials or privileged service configuration. |
| NFR-57 | The system shall undergo automated end-to-end testing of core GUI workflows. |
| NFR-58 | Frontend assets shall be included in the reproducible application deployment process. |

### 4. Document processing lifecycle

![Document processing lifecycle](./diagram.png)

### 5. Proposed API endpoints

| Method | Endpoint | Purpose |
| --- | --- | --- |
| POST | `/api/documents` | Upload a PDF |
| GET | `/api/documents` | List documents |
| GET | `/api/documents/{id}` | Retrieve metadata |
| GET | `/api/documents/{id}/status` | Retrieve processing status |
| GET | `/api/documents/{id}/download` | Download original PDF |
| GET | `/api/documents/{id}/results` | Retrieve processing results |
| DELETE | `/api/documents/{id}` | Delete a document |
| POST | `/api/documents/{id}/retry` | Reprocess a failed document |
| GET | `/health` | Application health check |

### 6. User interface specification

#### 6.1. Document dashboard

- PDF file selection and upload progress.
- Document list with filename, upload date, and current processing status.
- Summary counts of documents by processing status.
- Actions for viewing, downloading, and deleting documents.
- Automatic status updates through periodic API polling.

#### 6.2. Document details

- Filename, file size, page count, title, author, word count, and character count, where available.
- Processing status, timestamps, and failure reason, where applicable.
- Extracted text preview and download actions for the original PDF and processing results.
- Reprocessing action for authorized administrators when a document has failed.

#### 6.3. Presentation layer deployment

The GUI shall be served by the same EC2 application that hosts the REST API, accessed through the Application Load Balancer. It shall not require direct access to AWS services or a separate frontend deployment. Administrative authorization shall be enforced by the backend, not solely by the GUI.

The proposed frontend stack is HTML, CSS, Bootstrap, and vanilla JavaScript using the Fetch API.

### 7. Scope limitations

To keep the project focused on cloud engineering and distributed systems rather than document processing algorithms or frontend development, the following constraints apply:

- REST API and a basic web GUI limited to document management, processing status, and results.

- PDF files only, with an initial maximum size of 10 MB and 100 pages.

- Text extraction and metadata extraction only.

- No OCR, AI summarization, document editing, or conversion.

- No complex user account or multi-tenant management system; basic administrative authorization is required.

- Floci as the primary development and testing environment.

- Actual AWS deployment as an optional final milestone.

**Validation limitation:** Floci is the primary development environment. Production-specific behavior such as multi-AZ availability, infrastructure scaling, IAM enforcement, encryption, and AWS performance must remain unverified until tested on AWS.
