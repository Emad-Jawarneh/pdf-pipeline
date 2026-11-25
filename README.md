# pdf-pipeline
PDF Pipeline is an event-driven document processing platform designed to demonstrate cloud infrastructure provisioning, asynchronous processing, distributed system reliability, scalability, and observability using AWS services and Terraform.

The system allows users to upload PDF documents, automatically processes them through an asynchronous pipeline, and provides access to processing results and document metadata.

The entire application will initially operate in a local AWS emulation environment using Floci.

## Project structure

```text
src/
  api/                   REST API and document management
    web/                 Browser assets served by the API
  worker/
    processor/           Lambda handler and PDF extraction
    reconciliation/      Dead-letter queue failure reconciliation
infra/
  modules/               Reusable Terraform modules
  environments/
    local/               Terraform configuration for Floci
    aws/                 Terraform configuration for the optional AWS deployment
tests/
  unit/                  Application logic
  integration/           Service interactions
  e2e/                   Core browser workflows
  load/                  Performance and concurrency
  resilience/            Failure injection and recovery
.github/
  workflows/             GitHub Actions workflows
docs/                    Requirements, architecture, and diagrams
```
