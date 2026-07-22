#!/bin/bash
set -euo pipefail
cd /home/louie/ansible
ansible-playbook playbooks/apt-maintenance.yml
