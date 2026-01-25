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

# Subnet for MySQL
resource "azurerm_subnet" "mysql" {
  name                 = "${var.prefix}-mysql-subnet"
  resource_group_name  = azurerm_resource_group.nextcloud.name
  virtual_network_name = azurerm_virtual_network.nextcloud.name
  address_prefixes     = ["10.0.2.0/24"]
  
  delegation {
    name = "mysql-delegation"
    service_delegation {
      name = "Microsoft.DBforMySQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

# Private DNS Zone for MySQL
resource "azurerm_private_dns_zone" "mysql" {
  name                = "privatelink.mysql.database.azure.com"
  resource_group_name = azurerm_resource_group.nextcloud.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "mysql" {
  name                  = "${var.prefix}-mysql-vnet-link"
  resource_group_name   = azurerm_resource_group.nextcloud.name
  private_dns_zone_name = azurerm_private_dns_zone.mysql.name
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
  }
  
  tags = var.tags
}

# Storage Account for Nextcloud data
# Note: Storage account names must be 3-24 characters, lowercase letters and numbers only
# Adding random suffix to ensure global uniqueness
resource "random_id" "storage" {
  byte_length = 4
}

resource "azurerm_storage_account" "nextcloud" {
  name                     = lower(substr("${replace(var.prefix, "-", "")}${random_id.storage.hex}", 0, 24))
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

# MySQL Flexible Server
resource "random_password" "mysql" {
  length  = 24
  special = true
}

resource "azurerm_mysql_flexible_server" "nextcloud" {
  name                = "${var.prefix}-mysql"
  resource_group_name = azurerm_resource_group.nextcloud.name
  location            = azurerm_resource_group.nextcloud.location
  
  administrator_login    = var.mysql_admin_username
  administrator_password = random_password.mysql.result
  
  sku_name   = "B_Standard_B1s"
  version    = "8.0.21"
  
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  
  delegated_subnet_id = azurerm_subnet.mysql.id
  private_dns_zone_id = azurerm_private_dns_zone.mysql.id
  
  storage {
    size_gb           = 5  # 5GB minimum storage
    auto_grow_enabled = true
  }
  
  depends_on = [azurerm_private_dns_zone_virtual_network_link.mysql]
  
  tags = var.tags
}

resource "azurerm_mysql_flexible_database" "nextcloud" {
  name                = var.mysql_database_name
  resource_group_name = azurerm_resource_group.nextcloud.name
  server_name         = azurerm_mysql_flexible_server.nextcloud.name
  charset             = "utf8mb4"
  collation           = "utf8mb4_unicode_ci"
}

# Note: MySQL Flexible Server uses private endpoint via delegated subnet
# No public access is configured
