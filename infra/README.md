# Azure AI-Powered Serverless Image Pipeline

## What this stack does
- Upload images to Blob Storage → Function App creates thumbnails, calls Azure AI Vision for tags/captions, and upserts metadata into Cosmos DB.
- Static Web App (optional) lists images with tags/captions via the HTTP API in the Function App.
- Everything is instrumented with Application Insights and guarded by budget + lifecycle policies.

## Key architecture choices
- **Serverless-first:** Consumption plan for Functions, serverless Cosmos, S0 Vision.
- **Network isolation:** Virtual network with a dedicated integration subnet for the Function App and a private-endpoints subnet for Storage, Cosmos, and Key Vault. Public network access disabled on those services; private DNS zones wire up name resolution.
- **Secrets:** Keys stored in Key Vault; Function App reads via Key Vault references with managed identity.
- **Hygiene & cost:** Blob lifecycle deletes after 90 days (configurable). Optional monthly budget alert on the resource group.

## Terraform layout
- `infra/terraform/versions.tf` – Terraform/provider constraints.
- `infra/terraform/main.tf` – All Azure resources.
- `infra/terraform/variables.tf` – Tunables (prefix, regions, networking, budgets).
- `infra/terraform/dev.tfvars` – Dev defaults.
- `infra/terraform/outputs.tf` – Handy connection info.

## Deploy (when you choose to)
> Nothing is deployed by default. Run apply only for short demos, then destroy the resource group to avoid costs.
```bash
cd infra/terraform
terraform fmt
terraform init -upgrade
terraform plan -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

## Tear down
```bash
cd infra/terraform
terraform destroy -var-file=dev.tfvars
```

## Cost & safety
- Best $0 option: keep it undeployed and share code/screenshots.
- If you deploy on a trial, delete the RG after demo. Private endpoints incur small hourly cost; Vision charges per image; other services are serverless.
- To minimize spend during demos: set `vision_sku = "F0"`, set `public_network_access_enabled = true` on Storage/Cosmos/KV, and comment out private endpoints/DNS blocks.

## Networking summary
- VNet: `10.10.0.0/16` (override via `vnet_address_space`).
- Subnets:
  - `func-integration` (`10.10.1.0/24`) delegated to `Microsoft.Web/serverFarms` for Function VNet integration.
  - `private-endpoints` (`10.10.2.0/24`) for Storage/Cosmos/Key Vault private endpoints (network policies disabled as required).
- Private DNS zones linked to the VNet:
  - `privatelink.blob.core.windows.net`
  - `privatelink.documents.azure.com`
  - `privatelink.vaultcore.azure.net`

## Security highlights
- Public network access disabled on Storage, Cosmos, and Key Vault.
- Managed identity for the Function App; KV access policy grants only required `Get/List`.
- TLS 1.2 enforced; blob public access disabled; containers are private.
- Optional budget alert at 90% of monthly spend (`enable_budget`, `budget_amount`).

## Next improvements (nice-to-haves)
- Add CDN/SAS for serving images externally while keeping origins private.
- Add CI/CD (GitHub Actions) with Terraform validate/plan on PR and apply on main.
- Add App Insights workbook and alerts (error rate, Vision throttles, RU usage).
- Blue/green slots for the Function App; staged environments for Static Web Apps.
