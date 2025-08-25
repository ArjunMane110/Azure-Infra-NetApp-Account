variable "subrscription_id" {
  description = "The Azure subscription ID"
  type        = string
}

variable "tenant_id" {
  description = "The name of the tenant id"
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "East US"
}

variable "storage_account_name" {
  description = "Name of the storage account (must be globally unique)"
  type        = string
}

variable "admin_username" {
  description = "Admin username for the Windows VM"
  type        = string
}

variable "admin_password" {
  description = "Admin password for the Windows VM"
  type        = string
  sensitive   = true
}

variable "virtual_network_name" {
  description = "Name of the virtual network"
  type        = string
}

variable "subnet_name" {
  description = "Name of the subnet within the virtual network"
  type        = string
}

variable "netapp_account_name" {
  description = "Name of the NetApp account"
  type        = string
}

variable "ad_username" {
  description = "Active Directory username"
  type        = string
  sensitive   = true
}

variable "ad_password" {
  description = "Active Directory password"
  type        = string
  sensitive   = true
}

variable "smb_server_name" {
  description = "SMB server name"
  type        = string
}

variable "ad_dns_servers" {
  description = "DNS servers for AD"
  type        = list(string)
}

variable "ad_domain" {
  description = "AD Domain name"
  type        = string
}

variable "ad_organizational_unit" {
  description = "AD Organizational Unit"
  type        = string
}

variable "uai_name" {
  description = "Name of the User Assigned Managed Identity"
  type        = string
}

variable "netapp_pool_name" {
  description = "Name of the NetApp pool"
  type        = string
}

variable "service_level" {
  description = "Service level for the NetApp pool (e.g., Standard, Premium)"
  type        = string
}

variable "size_in_tb" {
  description = "Size of the NetApp pool in TB"
  type        = number
  default     = 4
}


### NFS volume ###
variable "netapp_volume_config" {
  type = object({
    name                = string
    location            = string
    resource_group_name = string
    account_name        = string
    pool_name           = string
    subnet_id           = string
    volume_path         = string # <-- make sure this is declared!
    service_level       = string
    protocols           = list(string)
    storage_quota_in_gb = number
  })
}

variable "netapp_volume_name" {
  description = "Name of the NetApp volume"
  type        = string
  default     = "devopsnetappvolume"
}

variable "volume_path" {
  description = "Path for the NetApp volume"
  type        = string
  default     = "volumepath"
}

variable "netapp_protocols" {
  description = "Protocols for the NetApp volume"
  type        = list(string)
  default     = ["SMB", "NFSv4.1"]
}

variable "backup_policy" {
  description = "Name of the Azure NetApp Files account"
  type        = string
}

variable "daily_backup" {
  description = "Quota for the NetApp volume in GB"
  type        = number
  default     = 20
}

variable "monthly_backup" {
  description = "Quota for the NetApp volume in GB"
  type        = number
  default     = 20
}

variable "weekly_backup" {
  description = "Quota for the NetApp volume in GB"
  type        = number
  default     = 20
}

variable "backup_vault" {
  description = "Name of the Azure NetApp Files account"
  type        = string
}

variable "volume_quota_in_gb" {
  description = "Quota for the NetApp volume in GB"
  default     = 100
  type        = number
}

variable "netapp_subnet_name" {
  description = "Subnet ID for the NetApp volume"
  type        = string
}

variable "netapp_virtual_network_name" {
  description = "Virtual network name for the NetApp volume"
  type        = string
}



### SMB VOlume ###

variable "smb_volume_config" {
  type = object({
    name                = string
    location            = string
    resource_group_name = string
    account_name        = string
    pool_name           = string
    subnet_id           = string
    volume_path         = string # <-- make sure this is declared!
    service_level       = string
    protocols           = list(string)
    storage_quota_in_gb = number
  })
}

variable "smb_volume_name" {
  description = "Name of the smb volume"
  type        = string
  default     = "devopssmbvolume"
}

variable "smb_volume_path" {
  description = "Path for the smb volume"
  type        = string
  default     = "devopssmbvolume"
}

variable "smb_protocols" {
  description = "Protocols for the smb volume"
  type        = list(string)
  default     = ["SMB", "CIFS"]
}

variable "smbvolume_quota_in_gb" {
  description = "Quota for the NetApp volume in GB"
  default     = 50
  type        = number
}
