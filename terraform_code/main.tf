# since these variables are re-used - a locals block makes this more maintainable
locals {
  openshift_api_url              = "${azurerm_redhat_openshift_cluster.aro_cluster.api_server_profile[0].url}"
  aro_app_name                   = "${var.resourcegroup_name}-app"
  aro_vnet_name                  = "${var.resourcegroup_name}-vnet"
  aro_master_subnet_name         = "${var.master_subnet}-${var.resourcegroup_name}"
  aro_worker_subnet_name         = "${var.worker_subnet}-${var.resourcegroup_name}"
  aro_master_subnet_cidr         = "${var.master_subnet_cidr}"
  aro_worker_subnet_cidr         = "${var.worker_subnet_cidr}"
  aro_vnet_cidr                  = "${var.vnet_cidr}"
  subscription                   = "${data.azurerm_client_config.azurerm_client.subscription_id}"
  client_id                      = "${data.azurerm_client_config.azurerm_client.client_id}"
  tenant                         = "${data.azurerm_client_config.azurerm_client.tenant_id}"
  secret                         = "${azuread_service_principal_password.azuread_sp_pwd.value}"
}

data "azurerm_client_config" "azurerm_client" {}

data "azuread_client_config" "azuread_client" {}

resource "azuread_application" "azuread_app" {
  display_name = local.aro_app_name
}

resource "azuread_service_principal" "azuread_sp" {
  client_id = azuread_application.azuread_app.client_id
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

output "console_url" {
  value = azurerm_redhat_openshift_cluster.aro_cluster.console_url
}

output "api_url" {
  value = azurerm_redhat_openshift_cluster.aro_cluster.api_server_profile[0].url
}

