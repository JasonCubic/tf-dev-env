# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.34.0" # https://github.com/hashicorp/terraform-provider-azurerm
    }
  }
}

# Configure the Microsoft Azure Provider
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
provider "azurerm" {
  use_oidc        = true
  tenant_id       = var.tenant_id       # Optional, could get this from ARM_TENANT_ID Environment Variable
  subscription_id = var.subscription_id # Optional, could get this from ARM_SUBSCRIPTION_ID Environment Variable
  client_id       = var.client_id       # Optional, could get this from ARM_CLIENT_ID Environment Variable
  client_secret   = var.client_secret   # Optional, could get this from ARM_CLIENT_SECRET Environment Variable
  features {}                           # required
}

# ---

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group
resource "azurerm_resource_group" "mtc-rg" {
  name     = "mtc-resources" # the name inside of azure
  location = "eastus"        # https://github.com/claranet/terraform-azurerm-regions/blob/master/REGIONS.md
  tags = {
    environment = "dev" # nice to know what environment your resources are deployed to
  }
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network
resource "azurerm_virtual_network" "mtc-vn" {
  name                = "mtc-network"
  resource_group_name = azurerm_resource_group.mtc-rg.name # tells terraform this is dependent on what is referenced
  location            = azurerm_resource_group.mtc-rg.location
  address_space       = ["10.123.0.0/16"]
  tags = {
    environment = "dev"
  }
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet
resource "azurerm_subnet" "mtc-subnet" {
  name                 = "mtc-subnet"
  resource_group_name  = azurerm_resource_group.mtc-rg.name
  virtual_network_name = azurerm_virtual_network.mtc-vn.name
  address_prefixes     = ["10.123.1.0/24"]
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group
resource "azurerm_network_security_group" "mtc-sg" {
  name                = "mtc-sg"
  location            = azurerm_resource_group.mtc-rg.location
  resource_group_name = azurerm_resource_group.mtc-rg.name
  tags = {
    environment = "dev"
  }
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_rule
resource "azurerm_network_security_rule" "mtc-dev-rule" { # allows for developer access
  name                        = "mtc-dev-rule"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*" # for Tcp or ICMP or whatever
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*" # you could put your public internet IP address here 123.123.123.123/32
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.mtc-rg.name
  network_security_group_name = azurerm_network_security_group.mtc-sg.name
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association
resource "azurerm_subnet_network_security_group_association" "mtc-sga" {
  subnet_id                 = azurerm_subnet.mtc-subnet.id
  network_security_group_id = azurerm_network_security_group.mtc-sg.id
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip
resource "azurerm_public_ip" "mtc-ip" {
  name                = "mtc-ip"
  resource_group_name = azurerm_resource_group.mtc-rg.name
  location            = azurerm_resource_group.mtc-rg.location
  allocation_method   = "Dynamic"
  tags = {
    environment = "dev"
  }
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface
resource "azurerm_network_interface" "mtc-nic" {
  name                = "mtc-nic"
  location            = azurerm_resource_group.mtc-rg.location
  resource_group_name = azurerm_resource_group.mtc-rg.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.mtc-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.mtc-ip.id
  }
  tags = {
    environment = "dev"
  }
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine
resource "azurerm_linux_virtual_machine" "mtc-vm" {
  name                  = "mtc-vm"
  resource_group_name   = azurerm_resource_group.mtc-rg.name
  location              = azurerm_resource_group.mtc-rg.location
  size                  = "Standard_B1s" # the free tier size - https://portal.azure.com/#view/Microsoft_Azure_Billing/FreeServicesBlade
  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.mtc-nic.id]

  # https://developer.hashicorp.com/terraform/language/functions/filebase64
  custom_data = filebase64("install-docker-on-vm.sh")

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/mtcazurekey.pub") # https://developer.hashicorp.com/terraform/language/functions/file
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  # https://developer.hashicorp.com/terraform/language/resources/provisioners/syntax
  provisioner "local-exec" {
    # https://developer.hashicorp.com/terraform/language/functions/templatefile
    command = templatefile("${var.host_os}-ssh-script.tpl", {
      hostname     = self.public_ip_address
      user         = "adminuser"
      identityfile = "~/.ssh/mtcazurekey"
    })
    # interpreter = ["powershell", "-Command"]
    # interpreter = ["bash", "-c"] # for linux
    # ternary https://developer.hashicorp.com/terraform/language/expressions/conditionals
    interpreter = var.host_os == "windows" ? ["powershell", "-Command"] : ["bash", "-c"]
  }

  tags = {
    environment = "dev"
  }
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/public_ip
data "azurerm_public_ip" "mtc-ip-data" {
  name                = azurerm_public_ip.mtc-ip.name
  resource_group_name = azurerm_resource_group.mtc-rg.name
  # https://developer.hashicorp.com/terraform/language/meta-arguments/depends_on
  depends_on = [
    azurerm_linux_virtual_machine.mtc-vm
  ]
}
# to see the values: terraform state show data.azurerm_public_ip.mtc-ip-data


# https://developer.hashicorp.com/terraform/language/values/outputs
output "public_ip_address" {
  # https://developer.hashicorp.com/terraform/language/expressions/strings
  value = "${azurerm_linux_virtual_machine.mtc-vm.name}: ${data.azurerm_public_ip.mtc-ip-data.ip_address}"
}
