# Lab 6 - Static website infrastructure defined in Terraform
# Deployed by GitHub Actions using OIDC (no stored secrets).

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Remote state: stored in Azure Storage, accessed with Entra ID (no storage keys)
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstatenate01"
    container_name       = "tfstate"
    key                  = "nate-site.tfstate"
    use_oidc             = true
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  features {}
  use_oidc                        = true
  resource_provider_registrations = "none" # providers are already registered; pipeline has no subscription-level rights
}

# Resource group is created by an admin in the portal.
# The pipeline only has Contributor on this one group (least privilege).
data "azurerm_resource_group" "site" {
  name = "rg-lab-tf"
}

# Storage account names must be globally unique, so add a random suffix
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_storage_account" "site" {
  name                     = "sttfsite${random_string.suffix.result}"
  resource_group_name      = data.azurerm_resource_group.site.name
  location                 = data.azurerm_resource_group.site.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  min_tls_version          = "TLS1_2"

  static_website {
    index_document     = "index.html"
    error_404_document = "404.html"
  }

  tags = {
    project    = "lab6"
    managed_by = "terraform"
  }
}

resource "azurerm_storage_blob" "index" {
  name                   = "index.html"
  storage_account_name   = azurerm_storage_account.site.name
  storage_container_name = "$web"
  type                   = "Block"
  content_type           = "text/html"
  source                 = "${path.module}/../site/index.html"
  content_md5            =
