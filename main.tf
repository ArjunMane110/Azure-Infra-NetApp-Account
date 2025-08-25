terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.39.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id # Replace with your valid subscription ID
  tenant_id       = var.tenant_id       # Replace with your valid tenant ID
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# Virtual Network
resource "azurerm_virtual_network" "main_vnet" {
  name                = var.virtual_network_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

# VM Subnet
resource "azurerm_subnet" "vm_subnet" {
  name                 = var.subnet_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.main_vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Network Security Group
resource "azurerm_network_security_group" "nsg" {
  name                = var.nsg_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowRDP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Storage Account
resource "azurerm_storage_account" "storage" {
  name                     = var.storage_account_name # must be globally unique
  resource_group_name      = var.resource_group_name
  account_kind             = "StorageV2"
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Public IPs
resource "azurerm_public_ip" "vm_pip" {
  count               = 2
  name                = "pip-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# NICs
resource "azurerm_network_interface" "vm_nic" {
  count               = 2
  name                = "nic-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_pip[count.index].id
  }
}

# Associate NSG with NICs
resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  count                     = 2
  network_interface_id      = azurerm_network_interface.vm_nic[count.index].id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Windows Virtual Machines
resource "azurerm_windows_virtual_machine" "vm" {
  count               = 2
  name                = "winvm-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = "Standard_B2ms"

  admin_username = var.admin_username
  admin_password = var.admin_password

  network_interface_ids = [azurerm_network_interface.vm_nic[count.index].id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "winvm-osdisk-${count.index}"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  provision_vm_agent = true
}

# NetApp Account
resource "azurerm_netapp_account" "netappaccount" {
  name                = var.netapp_account_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  active_directory {
    username            = var.ad_username
    password            = var.ad_password
    smb_server_name     = var.smb_server_name
    dns_servers         = var.ad_dns_servers
    domain              = var.ad_domain
    organizational_unit = var.ad_organizational_unit
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.uai.id]
  }
}

# User Assigned Identity
resource "azurerm_user_assigned_identity" "uai" {
  name                = var.uai_name
  location            = var.location
  resource_group_name = var.resource_group_name
}

# NetApp Capacity Pool
resource "azurerm_netapp_pool" "netapppool" {
  name                = var.netapp_pool_name
  location            = var.location
  resource_group_name = var.resource_group_name
  account_name        = var.netapp_account_name
  service_level       = "Premium"
  size_in_tb          = var.size_in_tb
}

# NetApp Volume (NFS)
resource "azurerm_netapp_volume" "nfs_volume" {
  name                = var.netapp_volume_config.name
  location            = var.netapp_volume_config.location
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_netapp_account.netappaccount.name
  pool_name           = azurerm_netapp_pool.netapppool.name
  volume_path         = var.netapp_volume_config.volume_path
  service_level       = var.netapp_volume_config.service_level
  subnet_id           = azurerm_subnet.netapp_subnet.id
  protocols           = var.netapp_volume_config.protocols
  storage_quota_in_gb = var.netapp_volume_config.storage_quota_in_gb

  export_policy_rule {
    rule_index          = 1
    unix_read_only      = false
    unix_read_write     = true
    allowed_clients     = ["0.0.0.0/0"]
    protocol            = ["NFSv4.1"]
    root_access_enabled = true
  }

  data_protection_backup_policy {
    backup_vault_id  = azurerm_netapp_backup_vault.backup.id
    backup_policy_id = azurerm_netapp_backup_policy.policy.id
    policy_enabled   = true
  }
}

# NetApp Backup Vault
resource "azurerm_netapp_backup_vault" "backup" {
  name                = var.backup_vault
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  account_name        = azurerm_netapp_account.netappaccount.name
}

# NetApp Backup Policy
resource "azurerm_netapp_backup_policy" "policy" {
  name                    = var.backup_policy
  location                = var.location
  resource_group_name     = azurerm_resource_group.rg.name
  account_name            = azurerm_netapp_account.netappaccount.name
  daily_backups_to_keep   = var.daily_backup
  weekly_backups_to_keep  = var.weekly_backup
  monthly_backups_to_keep = var.monthly_backup
  enabled                 = true
}

# NetApp Subnet
resource "azurerm_subnet" "netapp_subnet" {
  name                 = var.netapp_subnet_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.main_vnet.name
  address_prefixes     = ["10.0.1.0/24"]

  delegation {
    name = "netapp-delegation"
    service_delegation {
      name    = "Microsoft.Netapp/volumes"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# NetApp SMB Volume
resource "azurerm_netapp_volume" "smb_volume" {
  name                = var.smb_volume_config.name
  location            = var.smb_volume_config.location
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_netapp_account.netappaccount.name
  pool_name           = azurerm_netapp_pool.netapppool.name
  volume_path         = var.smb_volume_config.volume_path
  service_level       = var.smb_volume_config.service_level
  subnet_id           = azurerm_subnet.netapp_subnet.id
  protocols           = var.smb_volume_config.protocols
  storage_quota_in_gb = var.smb_volume_config.storage_quota_in_gb
}
