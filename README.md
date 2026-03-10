# Azure AI Image Pipeline (Serverless Demo)

Serverless Azure reference project: upload images → Azure Function creates thumbnails → Azure AI Vision generates tags/captions → Cosmos DB stores metadata → optional Static Web App/HTTP API serves a gallery. All infra is defined in Terraform; nothing is deployed by default (safe for $0 use).

## Repo layout
- `infra/` – Terraform for all Azure resources (Function App, Storage, Vision, Cosmos, Key Vault, networking).
- `function_app/` – Azure Functions (blob trigger + list API) in Python.
- `frontend/` – Vite/React gallery UI (optional).
- `docs/one-pager.md` – Portfolio one-pager (export to PDF).

## Deploy & tear down (pay-as-you-go)
> Not deployed by default. Run only when you’re ready to demo, then delete to avoid costs.

```bash
cd infra/terraform
terraform init
terraform plan -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars        # deploy

# Tear down
terraform destroy -var-file=dev.tfvars
```

## Cost & safety notes
- Keep spending at $0 by leaving it undeployed; code alone shows the design.
- If you do deploy, destroy the resource group after demos. Private endpoints and Vision calls consume credit; Function/Cosmos are serverless.

More detail: see `infra/README.md`. Portfolio summary: `docs/one-pager.md`.
