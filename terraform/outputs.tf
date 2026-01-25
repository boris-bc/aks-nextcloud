output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.nextcloud.name
}

output "aks_cluster_id" {
  description = "ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.nextcloud.id
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.nextcloud.name
}

output "mariadb_fqdn" {
  description = "FQDN of the MariaDB server"
  value       = azurerm_mariadb_server.nextcloud.fqdn
  sensitive   = true
}

output "mariadb_admin_username" {
  description = "Administrator username for MariaDB"
  value       = azurerm_mariadb_server.nextcloud.administrator_login
  sensitive   = true
}

output "mariadb_admin_password" {
  description = "Administrator password for MariaDB"
  value       = random_password.mariadb.result
  sensitive   = true
}

output "mariadb_database_name" {
  description = "Name of the MariaDB database"
  value       = azurerm_mariadb_database.nextcloud.name
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.nextcloud.name
}

output "storage_account_key" {
  description = "Primary access key for the storage account"
  value       = azurerm_storage_account.nextcloud.primary_access_key
  sensitive   = true
}

output "storage_share_name" {
  description = "Name of the file share for Nextcloud data"
  value       = azurerm_storage_share.nextcloud_data.name
}

output "kube_config" {
  description = "Kubernetes configuration"
  value       = azurerm_kubernetes_cluster.nextcloud.kube_config_raw
  sensitive   = true
}
