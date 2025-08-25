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
  subscription_id = var.subscription_id # Replace with your valid sub ID
  tenant_id       = var.tenant_id # Replace with your valid tenant ID
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "devops-lab-rg"
  location = "south africa north"
}

# Create a virtual network
resource "azurerm_virtual_network" "devops_vnet" {
  name                = "devopsVnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

# Create a subnet for the VMs
resource "azurerm_subnet" "vm_subnet" {
  name                 = "devops-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.devops_vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Network Security Group
# Create a Network Security Group (NSG) for the VMs
resource "azurerm_network_security_group" "devops_nsg" {
  name                = "devopsNSG"
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
# Create a storage account for the lab
resource "azurerm_storage_account" "devops_storage_account" {
  name                     = "devopslabstorage135" # must be globally unique
  resource_group_name      = var.resource_group_name
  account_kind             = "StorageV2"
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Public IP Addresses
# Create two public IPs for the Windows VMs
resource "azurerm_public_ip" "vm_public_ip" {
  count               = 2
  name                = "devops-pip-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"   # ✅ Must be static for Standard SKU
  sku                 = "Standard" # Optional if you explicitly need Standard
  zones               = ["1"]      # Optional (you can remove this if not using zonal deployment)
}

# Network Interface Cards (NICs)
# Create two NICs for the Windows VMs
resource "azurerm_network_interface" "vm_nic" {
  count               = 2
  name                = "devopsNIC-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_public_ip[count.index].id
  }
}

# Network Security Group Association
# Associate the NSG with the NICs of the VMs
resource "azurerm_network_interface_security_group_association" "devops_nic_nsg" {
  count                     = 2
  network_interface_id      = azurerm_network_interface.vm_nic[count.index].id
  network_security_group_id = azurerm_network_security_group.devops_nsg.id
}

# Windows Virtual Machines
# Create two Windows VMs in the specified resource group and subnet
resource "azurerm_windows_virtual_machine" "vm" {
  count               = 2
  name                = "devopsWinVM-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = "Standard_B2ms"

  admin_username = var.admin_username
  admin_password = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.vm_nic[count.index].id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "devopsWinOsDisk-${count.index}"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  provision_vm_agent = true
}

# Azure Active Directory Domain Services
# Create an Azure Active Directory Domain Services for the NetApp account
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
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.uai.id
    ]
  }
}

# User Assigned Identity
resource "azurerm_user_assigned_identity" "uai" {
  name                = "devopsuai"
  location            = var.location
  resource_group_name = var.resource_group_name
}


# NetApp Capacity Pool
resource "azurerm_netapp_pool" "netapppool" {
  name                = "devopsnetapppool"
  location            = var.location
  resource_group_name = var.resource_group_name
  account_name        = var.netapp_account_name
  service_level       = "Premium"
  size_in_tb          = 4
}

# NetApp Volume
resource "azurerm_netapp_volume" "netappvol" {
  name                = var.netapp_volume_name
  location            = var.netapp_volume_config.location
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_netapp_account.netappaccount.name
  pool_name           = azurerm_netapp_pool.netapppool.name
  volume_path         = "devopsnetappvolume"
  service_level       = "Premium"
  subnet_id           = azurerm_subnet.netapp_subnet.id
  protocols           = ["NFSv4.1"]
  storage_quota_in_gb = 100

  export_policy_rule {
    rule_index          = 1
    unix_read_only      = false
    unix_read_write     = true
    allowed_clients     = ["0.0.0.0/0"]
    protocol            = ["NFSv4.1"]
    root_access_enabled = true
  }

  data_protection_backup_policy {
    backup_vault_id  = azurerm_netapp_backup_vault.devops-backup-vault.id
    backup_policy_id = azurerm_netapp_backup_policy.weekly_backup.id
    policy_enabled   = true
  }
}

#netapp backup vault and policy
resource "azurerm_netapp_backup_vault" "devops-backup-vault" {
  name                = var.backup_vault
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  account_name        = azurerm_netapp_account.netappaccount.name
}

resource "azurerm_netapp_backup_policy" "weekly_backup" {
  name                    = var.backup_policy
  location                = var.location
  resource_group_name     = azurerm_resource_group.rg.name
  account_name            = azurerm_netapp_account.netappaccount.name
  daily_backups_to_keep   = var.daily_backup
  weekly_backups_to_keep  = var.weekly_backup
  monthly_backups_to_keep = var.monthly_backup
  enabled                 = true
}

# Create a subnet for the NetApp volume
resource "azurerm_subnet" "netapp_subnet" {
  name                 = "netapp-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]

  delegation {
    name = "netapp-delegation"

    service_delegation {
      name = "Microsoft.Netapp/volumes"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action"
      ]
    }
  }
}

# Create a virtual network for the NetApp volume
resource "azurerm_virtual_network" "vnet" {
  name                = "devops-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

### SMB Volume ###

resource "azurerm_netapp_volume" "smbvolume" {
  name                = var.smb_volume_name
  location            = var.smb_volume_config.location
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_netapp_account.netappaccount.name
  pool_name           = azurerm_netapp_pool.netapppool.name
  volume_path         = "devopssmbvolume"
  service_level       = "Premium"
  subnet_id           = azurerm_subnet.netapp_subnet.id
  protocols           = ["CIFS"]
  storage_quota_in_gb = 50
}
