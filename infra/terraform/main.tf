resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

locals {
  name_suffix = random_string.suffix.result
  prefix      = lower(var.prefix)
  tags        = merge(var.tags, { "project" = var.prefix })
}

resource "azurerm_resource_group" "rg" {
  name     = "${local.prefix}-rg"
  location = var.location
  tags     = local.tags
}

# Storage account (used for blob uploads, thumbnails, and as Functions storage)
resource "azurerm_storage_account" "images" {
  name                            = replace("${local.prefix}sa${local.name_suffix}", "-", "")
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  public_network_access_enabled   = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  tags                            = local.tags
}

resource "azurerm_storage_container" "images" {
  name                  = var.image_container
  storage_account_name  = azurerm_storage_account.images.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "thumbnails" {
  name                  = var.thumbnail_container
  storage_account_name  = azurerm_storage_account.images.name
  container_access_type = "private"
}

resource "azurerm_storage_management_policy" "cleanup" {
  storage_account_id = azurerm_storage_account.images.id

  rule {
    name    = "delete-old-blobs"
    enabled = true

    filters {
      blob_types   = ["blockBlob"]
      prefix_match = ["${var.image_container}/", "${var.thumbnail_container}/"]
    }

    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = var.storage_delete_after_days
      }
    }
  }
}

# Private DNS zones
resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone" "cosmos" {
  name                = "privatelink.documents.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone" "kv" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                  = "blob-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "cosmos" {
  name                  = "cosmos-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.cosmos.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "kv" {
  name                  = "kv-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.kv.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

# Application Insights
resource "azurerm_application_insights" "appinsights" {
  name                = "${local.prefix}-appi-${local.name_suffix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"
  retention_in_days   = 30
  tags                = local.tags
}

# Networking (VNet + subnets)
resource "azurerm_virtual_network" "vnet" {
  name                = "${local.prefix}-vnet-${local.name_suffix}"
  address_space       = var.vnet_address_space
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags
}

resource "azurerm_subnet" "function_integration" {
  name                 = "func-integration"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_function_prefix]

  delegation {
    name = "functionapp-delegation"
    service_delegation {
      name = "Microsoft.Web/serverFarms"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action",
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

resource "azurerm_subnet" "private_endpoints" {
  name                                          = "private-endpoints"
  resource_group_name                           = azurerm_resource_group.rg.name
  virtual_network_name                          = azurerm_virtual_network.vnet.name
  address_prefixes                              = [var.subnet_endpoints_prefix]
  private_endpoint_network_policies             = "Disabled"
  private_link_service_network_policies_enabled = false
}

# Function consumption plan
resource "azurerm_service_plan" "functions" {
  name                = "${local.prefix}-plan-${local.name_suffix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "Y1" # Consumption
  tags                = local.tags
}

# Cognitive Services (Computer Vision)
resource "azurerm_cognitive_account" "vision" {
  name                          = "${local.prefix}-vision-${local.name_suffix}"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  kind                          = "CognitiveServices"
  sku_name                      = var.vision_sku
  custom_subdomain_name         = "${local.prefix}-${local.name_suffix}-vision"
  public_network_access_enabled = false
  tags                          = local.tags
}

# Key Vault for secrets (Vision + Cosmos keys)
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {
  name                          = "${local.prefix}-kv-${local.name_suffix}"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  purge_protection_enabled      = false
  soft_delete_retention_days    = 7
  public_network_access_enabled = true
  tags                          = local.tags
}

resource "azurerm_key_vault_access_policy" "functions" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_function_app.app.identity[0].principal_id

  secret_permissions = ["Get", "List"]
}

resource "azurerm_key_vault_access_policy" "admin" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = ["Get", "List", "Set", "Delete", "Purge", "Recover"]
}

resource "azurerm_key_vault_secret" "vision_key" {
  name         = "vision-key"
  value        = azurerm_cognitive_account.vision.primary_access_key
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_secret" "cosmos_key" {
  name         = "cosmos-key"
  value        = azurerm_cosmosdb_account.cosmos.primary_key
  key_vault_id = azurerm_key_vault.kv.id
}

# Cosmos DB (serverless) for metadata
resource "azurerm_cosmosdb_account" "cosmos" {
  name                = "${local.prefix}-cosmos-${local.name_suffix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  capabilities {
    name = "EnableServerless"
  }

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = azurerm_resource_group.rg.location
    failover_priority = 0
  }

  public_network_access_enabled = false
  tags                          = local.tags
}

resource "azurerm_cosmosdb_sql_database" "db" {
  name                = var.cosmos_db_name
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmos.name
}

resource "azurerm_cosmosdb_sql_container" "container" {
  name                = var.cosmos_container_name
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmos.name
  database_name       = azurerm_cosmosdb_sql_database.db.name
  partition_key_paths = ["/id"]
  indexing_policy {
    indexing_mode = "consistent"
  }
}

# Linux Function App
resource "azurerm_linux_function_app" "app" {
  name                       = "${local.prefix}-func-${local.name_suffix}"
  resource_group_name        = azurerm_resource_group.rg.name
  location                   = azurerm_resource_group.rg.location
  service_plan_id            = azurerm_service_plan.functions.id
  storage_account_name       = azurerm_storage_account.images.name
  storage_account_access_key = azurerm_storage_account.images.primary_access_key
  https_only                 = true
  virtual_network_subnet_id  = azurerm_subnet.function_integration.id

  site_config {
    application_stack {
      python_version = "3.10"
    }
    http2_enabled          = true
    vnet_route_all_enabled = true
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    FUNCTIONS_EXTENSION_VERSION           = "~4"
    AzureWebJobsStorage                   = azurerm_storage_account.images.primary_connection_string
    WEBSITE_RUN_FROM_PACKAGE              = "1"
    APPINSIGHTS_INSTRUMENTATIONKEY        = azurerm_application_insights.appinsights.instrumentation_key
    APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.appinsights.connection_string

    VISION_ENDPOINT = azurerm_cognitive_account.vision.endpoint
    VISION_KEY      = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.vision_key.id})"

    COSMOS_ENDPOINT       = azurerm_cosmosdb_account.cosmos.endpoint
    COSMOS_KEY            = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.cosmos_key.id})"
    COSMOS_DB_NAME        = azurerm_cosmosdb_sql_database.db.name
    COSMOS_CONTAINER_NAME = azurerm_cosmosdb_sql_container.container.name

    IMAGE_CONTAINER     = var.image_container
    THUMBNAIL_CONTAINER = var.thumbnail_container
  }

  tags = local.tags
}

# Optional: Static Web App (disabled by default to avoid needing a GitHub token)
resource "azurerm_static_site" "swa" {
  count               = var.enable_static_web_app ? 1 : 0
  name                = "${local.prefix}-swa-${local.name_suffix}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.swa_location
  sku_tier            = "Free"
  sku_size            = "Free"

  tags = local.tags

  identity {
    type = "SystemAssigned"
  }
}

# Cost guardrail (optional)
resource "azurerm_consumption_budget_resource_group" "monthly" {
  count             = var.enable_budget ? 1 : 0
  name              = "${local.prefix}-rg-budget"
  resource_group_id = azurerm_resource_group.rg.id
  amount            = var.budget_amount
  time_grain        = "Monthly"

  time_period {
    start_date = formatdate("YYYY-MM-01", timestamp())
  }

  notification {
    enabled       = true
    threshold     = 90
    operator      = "GreaterThan"
    contact_roles = ["Owner"]
  }
}

# Private endpoints
resource "azurerm_private_endpoint" "storage_blob" {
  name                = "${local.prefix}-pe-blob-${local.name_suffix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "blob-connection"
    private_connection_resource_id = azurerm_storage_account.images.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  private_dns_zone_group {
    name                 = "blob-dns"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }
}

resource "azurerm_private_endpoint" "cosmos" {
  name                = "${local.prefix}-pe-cosmos-${local.name_suffix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "cosmos-connection"
    private_connection_resource_id = azurerm_cosmosdb_account.cosmos.id
    is_manual_connection           = false
    subresource_names              = ["Sql"]
  }

  private_dns_zone_group {
    name                 = "cosmos-dns"
    private_dns_zone_ids = [azurerm_private_dns_zone.cosmos.id]
  }
}

resource "azurerm_private_endpoint" "kv" {
  name                = "${local.prefix}-pe-kv-${local.name_suffix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "kv-connection"
    private_connection_resource_id = azurerm_key_vault.kv.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                 = "kv-dns"
    private_dns_zone_ids = [azurerm_private_dns_zone.kv.id]
  }
}
