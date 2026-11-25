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

## Initialize the development environment

Build the API and worker projects with the .NET 10 SDK.

```sh
dotnet build PdfPipeline.slnx
dotnet run --project src/api/PdfPipeline.Api.csproj -- --urls http://localhost:5080
```

The API exposes `GET /health` at `http://localhost:5080/health`. The worker projects are class library scaffolds for the processor and reconciliation handlers.

Initialize and validate the Terraform roots independently. The local root points the pipeline services at Floci. The AWS root accepts `TF_VAR_aws_region` for a future deployment. Both roots currently contain provider configuration only.

```sh
terraform fmt -check -recursive infra
terraform -chdir=infra/environments/local init
terraform -chdir=infra/environments/local validate
terraform -chdir=infra/environments/aws init
terraform -chdir=infra/environments/aws validate
```

When using Floci, override its default URL with `TF_VAR_floci_endpoint` if needed, and supply dummy AWS credentials in your local shell. [Floci AWS setup](https://github.com/floci-io/floci/blob/main/docs/getting-started/aws-setup.md)
