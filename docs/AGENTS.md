# AGENTS.md

## Project Overview

PDF Pipeline is an event-driven PDF processing platform designed to demonstrate cloud infrastructure, asynchronous processing, fault tolerance, and infrastructure as code using AWS-compatible services, Terraform, and Floci.

The project accepts PDF documents through a REST API or a lightweight web interface, processes them asynchronously, and makes extracted text, metadata, processing status, and results available to the user.

Floci is the primary local development and testing environment. AWS is the target architecture; deployment to AWS is optional.

## Sources of Truth

Before making changes, inspect the existing implementation and relevant repository documentation, particularly `README.md`, `docs/SRS.md`, architecture diagrams, and API documentation where available.

- Treat approved requirements and architectural decisions as the source of truth.
- Do not silently resolve contradictions between documentation and implementation. Identify the conflict and request clarification when it affects the requested change.
- Do not introduce requirements, technologies, dependencies, or architectural changes without justification.
- Update affected documentation when an approved change alters behavior, configuration, or architecture.

## Architecture

The intended AWS architecture consists of:

| Component | Responsibility |
| --- | --- |
| VPC, ALB, EC2 Auto Scaling Group | Network isolation, API hosting and request distribution |
| Amazon S3 | Original PDF and processing result storage |
| Amazon EventBridge | Routing document upload events |
| Amazon SQS | Asynchronous job buffering and delivery |
| AWS Lambda | PDF processing |
| Amazon DynamoDB | Document metadata and processing state |
| SQS dead-letter queue | Isolation of repeatedly failed jobs |
| AWS IAM | Least-privilege service access |
| Amazon CloudWatch | Logging, monitoring and operational visibility |
| Terraform | Reproducible infrastructure provisioning |
| GitHub Actions | Automated checks and CI/CD, where configured |

The main processing flow is:

```text
Client / GUI -> ALB -> EC2 REST API -> S3 (original PDF)
                                         |
                                         v
                              EventBridge -> SQS -> Lambda
                                                       |
                                                       +-> S3 (results)
                                                       +-> DynamoDB (status)
```

The API also creates and queries document metadata in DynamoDB. The GUI is served by the API application using HTML, CSS, Bootstrap and vanilla JavaScript, rather than introducing a separate frontend service.

## Functional and Architectural Constraints

- Accept PDF documents only, with a maximum size of 10 MB and a maximum of 100 pages.
- Validate files before accepting them for processing; do not rely solely on file extensions or client-provided MIME types.
- Return HTTP `202 Accepted` after a valid upload has been accepted for asynchronous processing; do not wait for extraction to finish.
- Limit processing to text, metadata and documented document statistics. Do not introduce OCR, AI summarization, PDF editing, format conversion or complex user account management.
- Keep API handlers, PDF processing logic, persistence and infrastructure concerns separate.
- Treat S3 as the document and result store, and DynamoDB as the authoritative source for processing status.
- Preserve the documented API routes, response contracts and state transitions. Do not invent undocumented public API behavior.

## Reliability and State Management

- Assume asynchronous messages can be duplicated, delayed or delivered out of order.
- Make processing idempotent using conditional DynamoDB writes, processing versions and deterministic result keys where applicable.
- Prevent invalid state transitions and stale processing attempts from overwriting newer results.
- Use the documented states: `UPLOADED`, `QUEUED` (if implemented), `PROCESSING`, `RETRYING`, `COMPLETED` and `FAILED`.
- Mark a document as completed only after the required results have been persisted successfully.
- Use bounded retries and a dead-letter queue. Preserve the documented baseline of three processing attempts, a 60-second Lambda timeout, a 360-second SQS visibility timeout and four-day queue retention unless requirements change.
- Reconcile terminal processing failures with DynamoDB status. Do not leave documents indefinitely marked as processing after retry exhaustion.
- Permit deletion only in documented terminal states; validate the eligibility of manual retries.
- Do not hide failures or replace reliability mechanisms with arbitrary delays.

## Infrastructure and Local Development

- Manage infrastructure through Terraform; avoid undocumented manual resource creation.
- Separate environment-specific configuration from application logic.
- Make AWS SDK and service endpoints configurable for Floci and real AWS environments.
- Use the repository's existing Terraform provider, modules, conventions and configuration when available.
- Run `terraform fmt -check` and `terraform validate` when infrastructure changes and prerequisites are available.
- Review Terraform plans before applying changes. Do not apply or destroy infrastructure without explicit authorization.
- Do not assume Floci reproduces all AWS service behavior. Verify emulator support before relying on a feature and document relevant limitations.
- Never claim that a locally emulated integration has been validated on real AWS unless it has actually been tested there.

## Code and Security Standards

- Follow the existing language, framework, formatting and naming conventions. If no implementation stack has been selected, do not select one implicitly.
- Prefer straightforward, maintainable code over premature abstractions and unnecessary dependencies.
- Keep changes focused on the requested task. Avoid unrelated refactoring or repository restructuring.
- Use least-privilege IAM policies and avoid public S3 access unless explicitly required and approved.
- Never commit credentials, secrets, private keys, Terraform state files or sensitive local configuration.
- Validate external inputs, use safe document identifiers and object keys, and handle malformed PDFs and resource limits.
- Do not log document contents, credentials or other sensitive information.
- Use structured logs with document identifiers and processing context to support debugging and tracing.

## Testing and Verification

Use the existing test framework and commands. Do not introduce a new testing framework without justification.

For relevant changes, cover:

- Valid, invalid, oversized and malformed PDF uploads.
- API response codes and documented response contracts.
- Successful asynchronous processing and result retrieval.
- Duplicate messages, conditional state updates and idempotency.
- Transient processing failures, retry exhaustion and DLQ handling.
- Manual retries, deletion eligibility and invalid state transitions.
- Terraform validation and supported Floci integration flows.

Run relevant tests and checks before reporting completion when the environment permits. Clearly distinguish verified behavior, untested behavior and emulator limitations. Never fabricate test results or claim checks passed if they were not run.

## Agent Workflow

1. Inspect relevant code, configuration and documentation before editing.
2. Identify affected components and constraints; for substantial changes, outline the proposed approach before implementation.
3. Implement the smallest coherent change that satisfies the request.
4. Add or update relevant tests and documentation.
5. Run available verification commands and review the resulting diff.
6. Summarize changes, verification results, assumptions and remaining issues.

Explain significant architectural decisions and trade-offs so the project owner can understand and maintain the implementation. Do not modify unrelated files, overwrite existing user work, commit, push, deploy, or perform destructive operations unless explicitly requested.
