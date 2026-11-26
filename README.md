# PDF Pipeline

PDF Pipeline is an event-driven document processing project built around .NET, AWS services, and Terraform. The planned REST API and web interface will let users upload PDFs, track processing, and retrieve extracted text, metadata, and document statistics.

Local development targets Floci, an AWS emulator. Deployment to AWS is an optional milestone.

## Current status

The repository contains an ASP.NET Core API with a `GET /health` endpoint, .NET class library scaffolds for the processing and reconciliation workers, and Terraform provider configurations for Floci and AWS. Uploads, the browser interface, PDF processing, and resource provisioning are planned.

## Planned workflow

1. The API validates the PDF, creates a document record in DynamoDB, and stores the original in S3. It returns `202 Accepted` after both writes succeed.
2. The S3 object creation event passes through EventBridge and SQS to a Lambda worker.
3. The worker extracts text and metadata, calculates word and character counts, stores the result in a separate S3 bucket, and updates DynamoDB.
4. The client checks status and downloads the result through the API. SQS retries transient failures, and dead-letter queue reconciliation records exhausted jobs as failed.

The initial design covers text-based PDFs up to 10 MB and 100 pages.

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

## Quick start

### Start and stop the local environment

On Linux, install the .NET 10 SDK, Docker Compose, `curl`, and `flock`. The scripts use a Floci checkout next to this repository. Set `FLOCI_DIR` to use a different checkout.

```sh
./scripts/start-environment.sh
./scripts/stop-environment.sh
```

The start script runs the `floci` Compose service and starts the API in the background. The API binds to `127.0.0.1:5080` by default. Set `PDFPIPELINE_API_PORT` to change the port. API logs are in `.local-run/api.log`. The stop script stops the API and the configured Floci service, preserving its container and persistent data. Terraform remains a separate step.

### Build and run the API

With the .NET 10 SDK installed, run these commands from the repository root.

```sh
dotnet build PdfPipeline.slnx
dotnet run --project src/api/PdfPipeline.Api.csproj -- --urls http://localhost:5080
```

From another terminal, check that the API responds with `Healthy`.

```sh
curl --fail http://localhost:5080/health
```

### Initialize Terraform

Use Terraform 1.5 or later in the 1.x series. Initialize and validate each environment independently from the repository root.

```sh
terraform fmt -check -recursive infra
terraform -chdir=infra/environments/local init
terraform -chdir=infra/environments/local validate
terraform -chdir=infra/environments/aws init
terraform -chdir=infra/environments/aws validate
```

The local root defaults to `http://localhost:4566` and `us-east-1`. Override them with `TF_VAR_floci_endpoint` and `TF_VAR_aws_region` as needed. Use dummy AWS credentials in your local shell when connecting to Floci. The AWS root requires an explicit region when planning a deployment. [Floci AWS setup](https://github.com/floci-io/floci/blob/main/docs/getting-started/aws-setup.md)

## Design documentation

- [System requirements](docs/system-requirements.md) covers scope, planned API routes, and acceptance targets.
- [Architecture](docs/architecture.md) covers the processing workflow, retries, deployment, and the DynamoDB schema.
