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

output "mysql_fqdn" {
  description = "FQDN of the MySQL server"
  value       = azurerm_mysql_flexible_server.nextcloud.fqdn
  sensitive   = true
}

output "mysql_admin_username" {
  description = "Administrator username for MySQL"
  value       = azurerm_mysql_flexible_server.nextcloud.administrator_login
  sensitive   = true
}

output "mysql_admin_password" {
  description = "Administrator password for MySQL"
  value       = random_password.mysql.result
  sensitive   = true
}

output "mysql_database_name" {
  description = "Name of the MySQL database"
  value       = azurerm_mysql_flexible_database.nextcloud.name
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
