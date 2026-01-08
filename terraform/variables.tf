variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "nextcloud-rg"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "westeurope"
}

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "nextcloud"
}

variable "node_count" {
  description = "Initial number of nodes in the AKS cluster"
  type        = number
  default     = 2
}

variable "min_node_count" {
  description = "Minimum number of nodes for autoscaling"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum number of nodes for autoscaling"
  type        = number
  default     = 5
}

variable "vm_size" {
  description = "VM size for AKS nodes"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "postgres_admin_username" {
  description = "Administrator username for PostgreSQL"
  type        = string
  default     = "nextcloudadmin"
}

variable "postgres_database_name" {
  description = "Name of the PostgreSQL database"
  type        = string
  default     = "nextcloud"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "production"
    ManagedBy   = "terraform"
    Project     = "nextcloud"
  }
}
