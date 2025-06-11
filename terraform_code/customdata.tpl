#!/bin/bash
rpm --import https://packages.microsoft.com/keys/microsoft.asc
yum install -y https://packages.microsoft.com/config/rhel/8/packages-microsoft-prod.rpm
yum install -y ansible-core git python3.12-pip jq azure-cli
sleep 10
runuser -l adminuser -c '
  pip3 install --upgrade pip
  sleep 10
  ansible-galaxy collection install community.general
  ansible-galaxy collection install community.okd
  pip3.12 install -r ~/.ansible/collections/ansible_collections/kubernetes/core/requirements.txt
  pip3.12 install -r  ~/.ansible/collections/ansible_collections/community/okd/requirements.txt
  pip3.12 install jmespath
  mkdir ~/.azure
  echo "[default]"                        >> ~/.azure/credentials
  echo "[default]"                        >> ~/.azure/credentials
  echo subscription_id=${subscription}    >> ~/.azure/credentials
  echo client_id=${client_id}             >> ~/.azure/credentials
  echo tenant=${tenant}                   >> ~/.azure/credentials
  echo secret=${secret}                   >> ~/.azure/credentials
'
