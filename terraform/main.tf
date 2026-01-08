terraform {
  required_version = ">= 1.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "nextcloud" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Virtual Network
resource "azurerm_virtual_network" "nextcloud" {
  name                = "${var.prefix}-vnet"
  location            = azurerm_resource_group.nextcloud.location
  resource_group_name = azurerm_resource_group.nextcloud.name
  address_space       = ["10.0.0.0/16"]
  tags                = var.tags
}

# Subnet for AKS
resource "azurerm_subnet" "aks" {
  name                 = "${var.prefix}-aks-subnet"
  resource_group_name  = azurerm_resource_group.nextcloud.name
  virtual_network_name = azurerm_virtual_network.nextcloud.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Subnet for PostgreSQL
resource "azurerm_subnet" "postgres" {
  name                 = "${var.prefix}-postgres-subnet"
  resource_group_name  = azurerm_resource_group.nextcloud.name
  virtual_network_name = azurerm_virtual_network.nextcloud.name
  address_prefixes     = ["10.0.2.0/24"]
  
  delegation {
    name = "postgres-delegation"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

# Private DNS Zone for PostgreSQL
resource "azurerm_private_dns_zone" "postgres" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.nextcloud.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "${var.prefix}-postgres-vnet-link"
  resource_group_name   = azurerm_resource_group.nextcloud.name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = azurerm_virtual_network.nextcloud.id
  tags                  = var.tags
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "nextcloud" {
  name                = "${var.prefix}-aks"
  location            = azurerm_resource_group.nextcloud.location
  resource_group_name = azurerm_resource_group.nextcloud.name
  dns_prefix          = "${var.prefix}-aks"
  
  default_node_pool {
    name                = "default"
    node_count          = var.node_count
    vm_size             = var.vm_size
    vnet_subnet_id      = azurerm_subnet.aks.id
    enable_auto_scaling = true
    min_count           = var.min_node_count
    max_count           = var.max_node_count
  }
  
  identity {
    type = "SystemAssigned"
  }
  
  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
    service_cidr      = "10.1.0.0/16"
    dns_service_ip    = "10.1.0.10"
    docker_bridge_cidr = "172.17.0.1/16"
  }
  
  tags = var.tags
}

# Storage Account for Nextcloud data
# Note: Storage account names must be 3-24 characters, lowercase letters and numbers only
resource "azurerm_storage_account" "nextcloud" {
  name                     = lower(substr(replace(var.prefix, "-", ""), 0, 20))
  resource_group_name      = azurerm_resource_group.nextcloud.name
  location                 = azurerm_resource_group.nextcloud.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  
  tags = var.tags
}

resource "azurerm_storage_share" "nextcloud_data" {
  name                 = "nextcloud-data"
  storage_account_name = azurerm_storage_account.nextcloud.name
  quota                = 100
}

# PostgreSQL Flexible Server
resource "random_password" "postgres" {
  length  = 24
  special = true
}

resource "azurerm_postgresql_flexible_server" "nextcloud" {
  name                   = "${var.prefix}-postgres"
  resource_group_name    = azurerm_resource_group.nextcloud.name
  location               = azurerm_resource_group.nextcloud.location
  version                = "14"
  administrator_login    = var.postgres_admin_username
  administrator_password = random_password.postgres.result
  storage_mb             = 32768
  sku_name               = "B_Standard_B1ms"
  zone                   = "1"
  
  # Security: Disable public network access - only accessible from VNet
  public_network_access_enabled = false
  delegated_subnet_id           = azurerm_subnet.postgres.id
  private_dns_zone_id           = azurerm_private_dns_zone.postgres.id
  
  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgres]
  
  tags = var.tags
}

resource "azurerm_postgresql_flexible_server_database" "nextcloud" {
  name      = var.postgres_database_name
  server_id = azurerm_postgresql_flexible_server.nextcloud.id
  collation = "en_US.utf8"
  charset   = "UTF8"
}

# Note: Firewall rules are not needed when public_network_access_enabled = false
# The database is only accessible from within the VNet via private endpoint
