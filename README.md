# Install Red Hat Advanced Cluster Security on an Azure Red Hat OpenShift (ARO) cluster leveraging Terraform and Ansible

Prerequisites and versions:

```
- Terraform (CLI): v1.12.1
- az (CLI): 2.74.0
- oc (CLI): version depend on the cluster version
- a public ssh key in the file `~/.ssh/id_rsa_aro.pub` for accessing the jumphost
- login to the Microsoft Azure infrastructure for the `az` client 
```
```
- ARO: 4.17
- ACS: 4.6
```

Clone the repository and change to repo directory:
```
$ https://github.com/agabriel81/terraform-ansible-aro-acs.git
$ cd terraform-ansible-aro-acs/terraform-code
```

Start the Terraform process by passing few variables:
```
$ export TF_VAR_pull_secret='{"auths":{"arosvc.azurecr.io....'
$ export TF_VAR_cluster_domain=agabriel-ger
$ export TF_VAR_cluster_version=4.17.27
$ export TF_VAR_location=germanywestcentral
$ export TF_VAR_resourcegroup_name=aro-ger-agabriel
$ export TF_VAR_cluster_name=aro-ger-cluster
$ export ARM_SUBSCRIPTION_ID=<your subscription ID>
```

Check if you want to override any variable (VNET, master/worker subnet name and CIDR etc) using the `override.tf_to_be_implemented` example file (by renaming it `override.tf`)

Deploy all Azure and OpenShift resources using Terraform:

```
$ terraform init
$ terraform validate
$ terraform plan 
$ terraform apply 
```

You'll receive the `console_url`, `api_url` and `jumphost public IP` at the end of the process

After completing the installation, retrieve ARO credentials, ARO console and ARO API URL:

```
$ az aro list-credentials --name ${TF_VAR_cluster_name} --resource-group ${TF_VAR_resourcegroup_name}
$ az aro show --name ${TF_VAR_cluster_name} --resource-group ${TF_VAR_resourcegroup_name} --query "consoleProfile.url" -o tsv
$ az aro show -g ${TF_VAR_resourcegroup_name} -n ${TF_VAR_cluster_name} --query apiserverProfile.url -o tsv 
$ oc login $(az aro show -g ${TF_VAR_resourcegroup_name} -n ${TF_VAR_cluster_name} --query apiserverProfile.url -o tsv) -u kubeadmin

```

A `jumhost` virtual machine was deployed and it's accessible via SSH through the Public IP and SSH key provided using the adminuser. 
This Virtual Machine is configured as an Ansible Controller (ansible-core, python, Ansible collection installed etc) where we can launch our Ansible playbook to deploy Red Hat Advanced Cluster Security.

Clone this repository and update `ansible.cfg` data with your Ansible Hub token to complete the Ansible Controller configuration.
Refresh the token:

```
https://console.redhat.com/ansible/automation-hub/token
```

Clone this repository:

```
$ git clone <repo>
```

A `custom_data` content was deployed in the `jumphost` host in the file `/var/lib/cloud/instance/scripts/part-001`, it's possible to review it and complete the configuration of the Ansbile Controller.

Make sure to export the K8S_AUTH_API_KEY as environment variable containing the token to authenticate to the OpenShift (ARO) cluster.

```
$ export K8S_AUTH_API_KEY=token
```

Review the `var_files.yaml` matching your ARO resources.

```
$ cd terraform-aro/ansible/vars
$ vi var_files.yaml
```

Start the Ansible Playbook:

```
$ cd terraform-aro/ansible
$ ansible-playbook playbook.yaml -e install_operator_name=rhacs-operator
```







REFERENCE

https://github.com/redhat-cop/agnosticd/blob/lb1153-1.2/ansible/roles_ocp_workloads/ocp4_workload_rhacs/tasks/workload.yml
https://registry.terraform.io/providers/hashicorp/azurerm/4.30.0/docs/resources/redhat_openshift_cluster
