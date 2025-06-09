#!/bin/bash
sleep 30
yum install -y ansible-core git python3.12-pip
sleep 10
runuser -l adminuser -c '
  pip3 install --upgrade pip
  sleep 10
  ansible-galaxy collection install community.general
  ansible-galaxy collection install community.okd
  pip3.12 install -r ~/.ansible/collections/ansible_collections/kubernetes/core/requirements.txt
  pip3.12 install -r  ~/.ansible/collections/ansible_collections/community/okd/requirements.txt
  pip3.12 install jmespath
'
