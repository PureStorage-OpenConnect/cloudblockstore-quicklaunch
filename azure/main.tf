terraform {
  required_providers {
    cbs = {
      source = "PureStorage-OpenConnect/cbs"
      version = "~> 0.6.0"
    }
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~> 2.70.0"
    }
    random = {
      source = "hashicorp/random"
      version = "~> 3.1.0"
    }
  }
  required_version = ">= 0.13"
}

provider "cbs" {
  azure {
    client_id = var.azure_client_id
    client_secret = var.azure_client_secret
    tenant_id = var.azure_tenant_id
    subscription_id = var.azure_subscription_id
  }
}

provider "azurerm" {
  features {}
  client_id = var.azure_client_id
  client_secret = var.azure_client_secret
  tenant_id = var.azure_tenant_id
  subscription_id = var.azure_subscription_id
}

resource "azurerm_marketplace_agreement" "plan" {
    publisher = "purestoragemarketplaceadmin"
    offer = "pure_storage_cloud_block_store_deployment"
    plan = var.plan_name
}

data "azurerm_client_config" "client_config" {}

resource "random_id" "vault_id" {
    byte_length = 8
}

resource "azurerm_resource_group" "azure_rg" {
  name     = format("%s%s", var.azure_resourcegroup, var.azure_location)
  location = var.azure_location
}

resource "azurerm_key_vault" "cbs_key_vault" {
    name                        = "CBS-${random_id.vault_id.hex}"
    location                    = azurerm_resource_group.azure_rg.location
    resource_group_name         = azurerm_resource_group.azure_rg.name
    tenant_id                   = data.azurerm_client_config.client_config.tenant_id
    sku_name = "standard"
    access_policy {
        tenant_id          = data.azurerm_client_config.client_config.tenant_id
        object_id          = data.azurerm_client_config.client_config.object_id
        secret_permissions = ["Get", "Set", "Delete", "List", "Recover"]
  }
}
resource "azurerm_public_ip" "azure_nat_ip" {
  name                = format("%s%s%s", var.azure_resourcegroup, var.azure_location, "-NAT-IP")
  location            = azurerm_resource_group.azure_rg.location
  resource_group_name = azurerm_resource_group.azure_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_nat_gateway" "cbs_nat_gateway" {
  name                    = format("%s%s%s", var.azure_resourcegroup, var.azure_location, "-NAT")
  location                = azurerm_resource_group.azure_rg.location
  resource_group_name     = azurerm_resource_group.azure_rg.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
}

resource "azurerm_nat_gateway_public_ip_association" "cbs_pub_ip_association" {
  nat_gateway_id       = azurerm_nat_gateway.cbs_nat_gateway.id
  public_ip_address_id = azurerm_public_ip.azure_nat_ip.id
}

resource "azurerm_virtual_network" "cbs_virtual_network" {
  name                = format("%s%s%s", var.azure_resourcegroup, var.azure_location, "-VNET")
  location            = azurerm_resource_group.azure_rg.location
  resource_group_name = azurerm_resource_group.azure_rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "cbs_subnet_sys" {
  name                 = format("%s%s%s", var.azure_resourcegroup, var.azure_location, "-SUBNET-SYS")
  resource_group_name  = azurerm_resource_group.azure_rg.name
  virtual_network_name = azurerm_virtual_network.cbs_virtual_network.name
  address_prefixes     = ["10.0.1.0/24"]
  service_endpoints    = ["Microsoft.AzureCosmosDB", "Microsoft.KeyVault"]
}

resource "azurerm_subnet" "cbs_subnet_mgmt" {
  name                 = format("%s%s%s", var.azure_resourcegroup, var.azure_location, "-SUBNET-MGMT")
  resource_group_name  = azurerm_resource_group.azure_rg.name
  virtual_network_name = azurerm_virtual_network.cbs_virtual_network.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_subnet" "cbs_subnet_repl" {
  name                 = format("%s%s%s", var.azure_resourcegroup, var.azure_location, "-SUBNET-REPL")
  resource_group_name  = azurerm_resource_group.azure_rg.name
  virtual_network_name = azurerm_virtual_network.cbs_virtual_network.name
  address_prefixes     = ["10.0.3.0/24"]
}

resource "azurerm_subnet" "cbs_subnet_iscsi" {
  name                 = format("%s%s%s", var.azure_resourcegroup, var.azure_location, "-SUBNET-ISCSI")
  resource_group_name  = azurerm_resource_group.azure_rg.name
  virtual_network_name = azurerm_virtual_network.cbs_virtual_network.name
  address_prefixes     = ["10.0.4.0/24"]
}


resource "azurerm_subnet_nat_gateway_association" "cbs_nat_gateway_association" {
  subnet_id      = azurerm_subnet.cbs_subnet_sys.id
  nat_gateway_id = azurerm_nat_gateway.cbs_nat_gateway.id
}

resource "azurerm_network_interface" "networkinterface" {
    name                = format("%s%s%s", var.azure_resourcegroup, var.azure_location, "-VM-INT")
    location            = azurerm_resource_group.azure_rg.location
    resource_group_name = azurerm_resource_group.azure_rg.name
    ip_configuration {
        name = format("%s%s%s", var.azure_resourcegroup, var.azure_location, "-VM-IP")
        subnet_id = azurerm_subnet.cbs_subnet_mgmt.id
        private_ip_address_allocation = var.azure_network_interface_ip_allocation
    }
}
// setup network peering for access from tf vnet to cbs vnet
data "azurerm_virtual_network" "tf_vnet" {
  name                = var.azure_virtualnetwork_peer_name
  resource_group_name = var.azure_virtualnetwork_peer_rg
}

resource "azurerm_virtual_network_peering" "tf_cbs" {
  name                      = "To-CBS-VNET"
  resource_group_name       = var.azure_virtualnetwork_peer_rg
  virtual_network_name      = data.azurerm_virtual_network.tf_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.cbs_virtual_network.id
}

resource "azurerm_virtual_network_peering" "cbs_tf" {
  name                      = "From-CBS-VNET"
  resource_group_name       = azurerm_resource_group.azure_rg.name
  virtual_network_name      = azurerm_virtual_network.cbs_virtual_network.name
  remote_virtual_network_id = data.azurerm_virtual_network.tf_vnet.id
}
resource "azurerm_linux_virtual_machine" "linux_vm" {
    name                = format("%s%s%s", var.azure_resourcegroup, var.azure_location, "-VM")
    resource_group_name = azurerm_resource_group.azure_rg.name
    location            = azurerm_resource_group.azure_rg.location
    size                = var.azure_vm_size
    admin_username      = var.azure_vm_username
    admin_password      = var.azure_vm_password
    disable_password_authentication = false
    network_interface_ids = [
        azurerm_network_interface.networkinterface.id,
    ]
    os_disk {
        caching              = "ReadWrite"
        storage_account_type = "Standard_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18_04-lts-gen2"
        version   = "latest"
    }
    boot_diagnostics {
    }
}

resource "cbs_array_azure" "azure_cbs" {

    array_name = format("%s%s%s", var.azure_resourcegroup, var.azure_location, "-CBS")
    location = azurerm_resource_group.azure_rg.location
    resource_group_name = azurerm_resource_group.azure_rg.name
    license_key = var.license_key
    log_sender_domain = var.log_sender_domain
    alert_recipients = var.alert_recipients
    array_model = var.array_model
    zone = var.zone
    virtual_network_id = azurerm_virtual_network.cbs_virtual_network.id
    key_vault_id = azurerm_key_vault.cbs_key_vault.id
    pureuser_private_key = file(var.key_file_path)
    management_subnet = azurerm_subnet.cbs_subnet_mgmt.name
    system_subnet = azurerm_subnet.cbs_subnet_sys.name
    iscsi_subnet = azurerm_subnet.cbs_subnet_iscsi.name
    replication_subnet = azurerm_subnet.cbs_subnet_repl.name

    jit_approval {
        approvers {
            groups = var.groups
        }
    }

    plan {
        name = var.plan_name
        product = var.plan_product
        publisher = var.plan_publisher
        version = var.plan_version
    }

    depends_on =[
      azurerm_linux_virtual_machine.linux_vm,
      azurerm_nat_gateway.cbs_nat_gateway,
      azurerm_nat_gateway_public_ip_association.cbs_pub_ip_association,
      azurerm_network_interface.networkinterface,
      azurerm_public_ip.azure_nat_ip,
      azurerm_resource_group.azure_rg,
      azurerm_subnet.cbs_subnet_iscsi,
      azurerm_subnet.cbs_subnet_mgmt,
      azurerm_subnet.cbs_subnet_repl,
      azurerm_subnet.cbs_subnet_sys,
      azurerm_subnet_nat_gateway_association.cbs_nat_gateway_association,
      azurerm_virtual_network.cbs_virtual_network,
      azurerm_marketplace_agreement.plan,
      azurerm_key_vault.cbs_key_vault,
      azurerm_virtual_network_peering.tf_cbs,
      azurerm_virtual_network_peering.cbs_tf
    ]
}

output "azure_vm_ip" {
    value = azurerm_linux_virtual_machine.linux_vm.private_ip_address
}
output "cbs_mgmt_endpoint" {
    value = cbs_array_azure.azure_cbs.management_endpoint
}
output "cbs_mgmt_endpoint_ct0" {
    value = cbs_array_azure.azure_cbs.management_endpoint_ct0
}
output "cbs_mgmt_endpoint_ct1" {
    value = cbs_array_azure.azure_cbs.management_endpoint_ct1
}
output "cbs_repl_endpoint_ct0" {
    value = cbs_array_azure.azure_cbs.replication_endpoint_ct0
}
output "cbs_repl_endpoint_ct1" {
    value = cbs_array_azure.azure_cbs.replication_endpoint_ct1
}
output "cbs_iscsi_endpoint_ct0" {
    value = cbs_array_azure.azure_cbs.iscsi_endpoint_ct0
}
output "cbs_iscsi_endpoint_ct1" {
    value = cbs_array_azure.azure_cbs.iscsi_endpoint_ct1
}