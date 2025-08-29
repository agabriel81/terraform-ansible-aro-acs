# Install Red Hat Advanced Cluster Security on an Azure Red Hat OpenShift (ARO) cluster leveraging Ansible (Ansible Navigator and Ansible EE) and Terraform

Prerequisites:

```
Podman running on your local machine, it will support the EE
ansible-navigator
git
```

Versions:

```
- ARO (Azure Red Hat OpenShift) version: 4.17
- RHACS (Red Hat Advanced Cluster Security) version: 4.8
- OpenShift Pipelines operator version: 1.18
```

Clone the repository, switch to the branch and change to the repository directory:
```
$ https://github.com/agabriel81/terraform-ansible-aro-acs.git
$ git checkout 4.17-4.8-plus-apps-ee
$ cd terraform-ansible-aro-acs/ansible
```

Pass required variables to the Terraform Collections:
```
$ export TF_VAR_pull_secret='{"auths":{"arosvc.azurecr.io....'
$ export TF_VAR_cluster_domain=agabriel-neu
$ export TF_VAR_cluster_version=4.17.27
$ export TF_VAR_location=northeurope
$ export TF_VAR_resourcegroup_name=aro-neu-agabriel
$ export TF_VAR_cluster_name=aro-neu-cluster
$ export TF_VAR_acs_password=<your Red Hat ACS password>
$ export TF_VAR_branch=<git branch in use>
$ export ARM_SUBSCRIPTION_ID=<your Azure Subscription ID>
$ export ARM_CLIENT_ID=<your Azure Client ID>
$ export ARM_CLIENT_SECRET=<your Azure Client Secret>
$ export ARM_TENANT_ID=<your Azure Tenant ID>
```

Check if you want to override any variable (VNET, master/worker subnet name and CIDR etc) using the `override.tf_to_be_implemented` example file (by renaming it `override.tf`)

Deploy all Azure and OpenShift resources using Ansible Navigator.
An `ansible-navigator.yml` file is already present to configure required environment variables and local mount point to leverage the Terraform code, state and plan

```
$ ansible-navigator run playbook.yaml
```

You'll receive the ACS route, ACS username/password, ARO `console_url`, ARO `api_url` and `jumphost public IP` at the end of the process.

After completing the installation, retrieve ARO credentials, ARO console and ARO API URL.
Below commands are possible from either your own box, according to the prerequisites, or via the `jumphost`.

```
$ az aro list-credentials --name ${TF_VAR_cluster_name} --resource-group ${TF_VAR_resourcegroup_name}
$ az aro show --name ${TF_VAR_cluster_name} --resource-group ${TF_VAR_resourcegroup_name} --query "consoleProfile.url" -o tsv
$ az aro show -g ${TF_VAR_resourcegroup_name} -n ${TF_VAR_cluster_name} --query apiserverProfile.url -o tsv 
$ oc login $(az aro show -g ${TF_VAR_resourcegroup_name} -n ${TF_VAR_cluster_name} --query apiserverProfile.url -o tsv) -u kubeadmin
```


REFERENCE

- https://github.com/redhat-cop/agnosticd/
- https://registry.terraform.io/providers/hashicorp/azurerm/4.30.0/docs/resources/redhat_openshift_cluster
- https://docs.ansible.com/ansible/latest/collections/community/okd/index.html
- https://docs.ansible.com/ansible/latest/collections/community/general/index.html
