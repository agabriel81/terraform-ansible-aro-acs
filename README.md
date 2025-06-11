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

Clone the repository, switch to the branch and change to the repository directory:
```
$ https://github.com/agabriel81/terraform-ansible-aro-acs.git
$ git checkout 4.17-4.6
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
$ export TF_VAR_acs_password=<your Red Hat ACS password>
$ export TF_VAR_branch=<git branch in use>
```

Check if you want to override any variable (VNET, master/worker subnet name and CIDR etc) using the `override.tf_to_be_implemented` example file (by renaming it `override.tf`)

Deploy all Azure and OpenShift resources using Terraform:

```
$ terraform init
$ terraform validate
$ terraform plan 
$ terraform apply 
```

A `jumhost` virtual machine was deployed and it's accessible via SSH through the Public IP and SSH key provided using the `adminuser`. 
This Virtual Machine is configured as an Ansible Controller (ansible-core, python, Ansible collection installed etc) where the Ansible playbook was launched in order to deploy Red Hat Advanced Cluster Security.

A `custom_data` content was deployed in the `jumphost` host for configuring it as an Ansible Controller via in the file `/var/lib/cloud/instance/scripts/part-001`.

You'll receive the ACS route, ACS username/password, ARO `console_url`, ARO `api_url` and `jumphost public IP` at the end of the process.

After completing the installation, retrieve ARO credentials, ARO console and ARO API URL.
Below commands are possible from either your own box, according to the prerequisites, or via the `jumphost`.

```
$ az aro list-credentials --name ${TF_VAR_cluster_name} --resource-group ${TF_VAR_resourcegroup_name}
$ az aro show --name ${TF_VAR_cluster_name} --resource-group ${TF_VAR_resourcegroup_name} --query "consoleProfile.url" -o tsv
$ az aro show -g ${TF_VAR_resourcegroup_name} -n ${TF_VAR_cluster_name} --query apiserverProfile.url -o tsv 
$ oc login $(az aro show -g ${TF_VAR_resourcegroup_name} -n ${TF_VAR_cluster_name} --query apiserverProfile.url -o tsv) -u kubeadmin
```

If it's needed to debug the Ansible playbook, please export the `K8S_AUTH_API_KEY` and `K8S_AUTH_HOST` in the `jumphost` Virtual Machine using:

```
$ source ~/.bashrc
```

The jumphost is equipped with the `az` CLI and `oc` CLI.
The ARO API token is saved into the `/tmp/openshift.token` both locally and in the `jumphost`.
The Azure environment credentials are saved into the `~/.azure/credentials` file.


REFERENCE

- https://github.com/redhat-cop/agnosticd/
- https://registry.terraform.io/providers/hashicorp/azurerm/4.30.0/docs/resources/redhat_openshift_cluster
- https://docs.ansible.com/ansible/latest/collections/community/okd/index.html
- https://docs.ansible.com/ansible/latest/collections/community/general/index.html
