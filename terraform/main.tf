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

# Note: MySQL will be deployed as a StatefulSet within the AKS cluster
# No dedicated subnet needed for containerized MySQL

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

# MySQL password for containerized MySQL deployment
# This will be used in Kubernetes secrets
resource "random_password" "mysql" {
  length  = 24
  special = true
}

# Note: MySQL is deployed as a StatefulSet within Kubernetes
# No Azure MySQL Flexible Server resources needed
