#!/bin/bash
sleep 30
sudo yum install -y ansible-core git python3.12-pip
sleep 10
sudo pip3 install --upgrade pip
sleep 10
ansible-galaxy collection install azure.azcollection
ansible-galaxy collection install redhat.openshift
sudo pip3.12 install -r ~/.ansible/collections/ansible_collections/kubernetes/core/requirements.txt
sudo pip3.12 install -r ~/.ansible/collections/ansible_collections/azure/azcollection/requirements.txt
sudo  pip3.12 install -r  ~/.ansible/collections/ansible_collections/redhat/openshift/requirements.txt
wget https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/4.17.27/openshift-client-linux-4.17.27.tar.gz

