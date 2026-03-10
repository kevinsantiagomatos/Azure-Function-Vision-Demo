variable "prefix" {
  description = "Short prefix for resource names (letters/numbers, <=10 chars)."
  type        = string
  default     = "imgai"
}

variable "location" {
  description = "Azure region for primary resources."
  type        = string
  default     = "eastus2"
}

variable "tags" {
  description = "Common resource tags."
  type        = map(string)
  default = {
    "owner" = "you"
    "env"   = "dev"
  }
}

variable "image_container" {
  description = "Blob container for original uploads."
  type        = string
  default     = "images"
}

variable "thumbnail_container" {
  description = "Blob container for generated thumbnails."
  type        = string
  default     = "thumbnails"
}

variable "vision_sku" {
  description = "SKU for the Azure AI Vision (Cognitive Services) account."
  type        = string
  default     = "S0"
}

variable "vnet_address_space" {
  description = "Address space for the project virtual network."
  type        = list(string)
  default     = ["10.10.0.0/16"]
}

variable "subnet_function_prefix" {
  description = "CIDR for the Function App integration subnet (delegated to Microsoft.Web/serverFarms)."
  type        = string
  default     = "10.10.1.0/24"
}

variable "subnet_endpoints_prefix" {
  description = "CIDR for private endpoint subnet."
  type        = string
  default     = "10.10.2.0/24"
}

variable "storage_delete_after_days" {
  description = "Lifecycle rule: delete blobs after this many days."
  type        = number
  default     = 90
}

variable "enable_budget" {
  description = "Whether to create a subscription-level monthly budget alert."
  type        = bool
  default     = false
}

variable "budget_amount" {
  description = "Monthly budget amount in USD (used when enable_budget is true)."
  type        = number
  default     = 25
}

variable "cosmos_db_name" {
  description = "Cosmos DB SQL database name."
  type        = string
  default     = "imagedb"
}

variable "cosmos_container_name" {
  description = "Cosmos DB SQL container name."
  type        = string
  default     = "metadata"
}

variable "enable_static_web_app" {
  description = "Whether to create a Static Web App (needs GitHub token & repo)."
  type        = bool
  default     = false
}

variable "swa_location" {
  description = "Region for Static Web App."
  type        = string
  default     = "westus2"
}

variable "swa_repository_url" {
  description = "Git repo URL for Static Web App deployment."
  type        = string
  default     = "https://github.com/your/repo"
}

variable "swa_branch" {
  description = "Branch to deploy for Static Web App."
  type        = string
  default     = "main"
}

variable "swa_github_token" {
  description = "GitHub PAT for Static Web App GitHub Actions (repo scope)."
  type        = string
  default     = ""
  sensitive   = true
}
