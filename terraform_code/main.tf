# since these variables are re-used - a locals block makes this more maintainable
locals {
  openshift_api_url              = "${azurerm_redhat_openshift_cluster.aro_cluster.api_server_profile[0].url}"
  jumphost_pip                   = "${var.cluster_name}-jumphost-pip"
  jumphost_subnet_cidr           = "${var.jumphost_subnet_cidr}"
  jumphost_nsg                   = "${var.cluster_name}-jumphost_nsg"
  aro_app_name                   = "${var.cluster_name}-app"
  aro_vnet_name                  = "${var.cluster_name}-vnet"
  jumphost_name                  = "${var.cluster_name}-jumphost"
  aro_custom_domain              = "${var.cluster_name}.openshift.internal"
  aro_master_subnet_name         = "${var.master_subnet}-${var.cluster_name}"
  aro_worker_subnet_name         = "${var.worker_subnet}-${var.cluster_name}"
  aro_master_subnet_cidr         = "${var.master_subnet_cidr}"
  aro_worker_subnet_cidr         = "${var.worker_subnet_cidr}"
  aro_vnet_cidr                  = "${var.vnet_cidr}"
  aro_vnet_link                  = "${var.cluster_name}-private-dns-link"
  subscription                   = "${data.azurerm_client_config.azurerm_client.subscription_id}"
  client_id                      = "${data.azurerm_client_config.azurerm_client.client_id}"
  tenant                         = "${data.azurerm_client_config.azurerm_client.tenant_id}"
  secret                         = "${azuread_service_principal_password.azuread_sp_pwd.value}"
}

data "azurerm_client_config" "azurerm_client" {}

data "azuread_client_config" "azuread_client" {}

resource "azuread_application_registration" "azuread_app" {
  display_name = local.aro_app_name
}

resource "azuread_service_principal" "azuread_sp" {
  client_id = azuread_application_registration.azuread_app.client_id
  app_role_assignment_required = false
  owners                       = [data.azuread_client_config.azuread_client.object_id]
}

resource "azuread_service_principal_password" "azuread_sp_pwd" {
  service_principal_id = azuread_service_principal.azuread_sp.object_id
  end_date             = "2025-12-31T23:59:59Z"     
}

data "azuread_service_principal" "redhatopenshift" {
  // This is the Azure Red Hat OpenShift RP service principal id, do NOT delete it
  client_id = "f1dd0a37-89c6-4e07-bcd1-ffd3d43d8875"
}

resource "azurerm_role_assignment" "role_network1" {
  scope                = azurerm_virtual_network.aro_vnet.id
  role_definition_name = "Network Contributor"
  principal_id         = azuread_service_principal.azuread_sp.object_id
}

resource "azurerm_role_assignment" "role_network2" {
  scope                = azurerm_virtual_network.aro_vnet.id
  role_definition_name = "Network Contributor"
  principal_id         = data.azuread_service_principal.redhatopenshift.object_id
}

resource "azurerm_resource_group" "aro_rg" {
  name     = var.resourcegroup_name
  location = var.location
}

resource "azurerm_virtual_network" "aro_vnet" {
  name                = local.aro_vnet_name
  address_space       = [local.aro_vnet_cidr]
  location            = var.location
  resource_group_name = azurerm_resource_group.aro_rg.name
}

resource "azurerm_subnet" "master_subnet" {
  name                 = local.aro_master_subnet_name
  resource_group_name  = azurerm_resource_group.aro_rg.name
  virtual_network_name = azurerm_virtual_network.aro_vnet.name
  address_prefixes     = [local.aro_master_subnet_cidr]
  service_endpoints    = ["Microsoft.Storage", "Microsoft.ContainerRegistry"]
  lifecycle {
    ignore_changes = all
  }
}

resource "azurerm_subnet" "worker_subnet" {
  name                 = local.aro_worker_subnet_name
  resource_group_name  = azurerm_resource_group.aro_rg.name
  virtual_network_name = azurerm_virtual_network.aro_vnet.name
  address_prefixes     = [local.aro_worker_subnet_cidr]
  service_endpoints    = ["Microsoft.Storage", "Microsoft.ContainerRegistry"]
}

resource "azurerm_subnet" "jumphost_subnet" {
  name                 = "JumpHostSubnet"
  resource_group_name  = azurerm_resource_group.aro_rg.name
  virtual_network_name = azurerm_virtual_network.aro_vnet.name
  address_prefixes     = [local.jumphost_subnet_cidr]
}

resource "azurerm_redhat_openshift_cluster" "aro_cluster" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = azurerm_resource_group.aro_rg.name

  cluster_profile {
    domain = var.cluster_domain
    version = var.cluster_version
    pull_secret = var.pull_secret
  }

  network_profile {
    pod_cidr     = "10.128.0.0/14"
    service_cidr = "172.30.0.0/16"
  }

  main_profile {
    vm_size   = "Standard_D8s_v3"
    subnet_id = azurerm_subnet.master_subnet.id
  }

  api_server_profile {
    visibility = "Public"
  }

  ingress_profile {
    visibility = "Public"
  }

  worker_profile {
    vm_size      = "Standard_D4s_v3"
    disk_size_gb = 128
    node_count   = 3
    subnet_id    = azurerm_subnet.worker_subnet.id
  }

  service_principal {
    client_id     = azuread_application_registration.azuread_app.client_id
    client_secret = azuread_service_principal_password.azuread_sp_pwd.value
  }

  depends_on = [
    azurerm_role_assignment.role_network1,
    azurerm_role_assignment.role_network2,
  ]
}

resource "azurerm_public_ip" "aro_jumphost_pip" {
  name                = local.jumphost_pip
  resource_group_name = azurerm_resource_group.aro_rg.name
  location            = azurerm_resource_group.aro_rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1","2","3"]
  domain_name_label   = var.cluster_name
}

resource "azurerm_network_interface" "jumphost_nic" {
  name                = local.jumphost_name
  location            = azurerm_resource_group.aro_rg.location
  resource_group_name = azurerm_resource_group.aro_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.jumphost_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.aro_jumphost_pip.id
  }
}

resource "azurerm_linux_virtual_machine" "jumphost" {
  name                = local.jumphost_name
  resource_group_name = azurerm_resource_group.aro_rg.name
  location            = azurerm_resource_group.aro_rg.location
  size                = "Standard_B2s"
  custom_data         = base64encode(templatefile("./customdata.tpl",
    {
      subscription = local.subscription,
      secret       = local.secret,
      tenant       = local.tenant,
      client_id    = local.client_id
    }))

  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.jumphost_nic.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa_aro.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "8-lvm-gen2"
    version   = "latest"
  }
}

resource "azurerm_network_security_group" "jumphost_nsg" {
  name                = local.jumphost_nsg
  location            = azurerm_resource_group.aro_rg.location
  resource_group_name = azurerm_resource_group.aro_rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "jumphost_nsg_association" {
  network_interface_id          = azurerm_network_interface.jumphost_nic.id
  network_security_group_id     = azurerm_network_security_group.jumphost_nsg.id
}

resource "null_resource" "get_ocp_token" {

  provisioner "local-exec" {
    command = <<EOT
#!/bin/bash
set -e

# Variables
CLUSTER_NAME="${var.cluster_name}"
RESOURCE_GROUP="${var.resourcegroup_name}"

# Get kubeadmin password
CREDENTIALS=$(az aro list-credentials --name "$CLUSTER_NAME" --resource-group "$RESOURCE_GROUP")
PASSWORD=$(echo "$CREDENTIALS" | jq -r '.kubeadminPassword')
USERNAME=$(echo "$CREDENTIALS" | jq -r '.kubeadminUsername')

# Login and extract token
oc login "${local.openshift_api_url}" -u "$USERNAME" -p "$PASSWORD" --insecure-skip-tls-verify=true

oc whoami -t > /tmp/openshift.token

echo "Token saved to openshift.token"
EOT
  }

  depends_on = [
    azurerm_redhat_openshift_cluster.aro_cluster
  ]
}

data "azurerm_public_ip" "jumphost_public_ip" {
  name                = azurerm_public_ip.aro_jumphost_pip.name
  resource_group_name = azurerm_linux_virtual_machine.jumphost.resource_group_name
}

resource "null_resource" "ansible_playbook" {
  depends_on = [null_resource.get_ocp_token]

  provisioner "file" {
    source      = "/tmp/openshift.token"
    destination = "/tmp/openshift.token"

    connection {
      type        = "ssh"
      user        = "adminuser"
      private_key = file("~/.ssh/id_rsa_aro")
      host        = data.azurerm_public_ip.jumphost_public_ip.ip_address
    }
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir ~/bin",
      "curl -k  https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/openshift-client-linux-amd64-rhel8.tar.gz| tar xfz - -C ~/bin",
      "echo 'export K8S_AUTH_HOST=${local.openshift_api_url}' >> ~/.bashrc",
      "echo 'export K8S_AUTH_API_KEY=$(cat /tmp/openshift.token)' >> ~/.bashrc",
      "source ~/.bashrc",
      "oc login $K8S_AUTH_HOST --token=$K8S_AUTH_API_KEY --insecure-skip-tls-verify=true",
      "git clone -b ${var.branch} https://github.com/agabriel81/terraform-ansible-aro-acs.git",
      "ansible-playbook /home/adminuser/terraform-ansible-aro-acs/ansible/playbook.yaml -e ocp4_workload_rhacs_central_admin_password=${var.acs_password} --skip-tags print_acs_info",
      "oc new-project acs-fake-apps",
      "oc apply -f ~/terraform-ansible-aro-acs/sample_applications/kubernetes-manifests/ --recursive",
      "oc apply -f ~/terraform-ansible-aro-acs/sample_applications/skupper-demo/ --recursive",
      "oc apply -f ~/terraform-ansible-aro-acs/sample_applications/openshift-pipelines/ --recursive",
      "ansible-playbook /home/adminuser/terraform-ansible-aro-acs/ansible/playbook.yaml -e ocp4_workload_rhacs_central_admin_password=${var.acs_password} --tags print_acs_info"
    ]

    connection {
      type        = "ssh"
      user        = "adminuser"
      private_key = file("~/.ssh/id_rsa_aro")
      host        = data.azurerm_public_ip.jumphost_public_ip.ip_address
    }
  }
}

output "console_url" {
  value = azurerm_redhat_openshift_cluster.aro_cluster.console_url
}

output "api_url" {
  value = azurerm_redhat_openshift_cluster.aro_cluster.api_server_profile[0].url
}

output "jumphost_public_ip" {
  value = data.azurerm_public_ip.jumphost_public_ip.ip_address
}
