#!/bin/env bash
#
# Runs `terraform plan` and outputs the plan to a file for later consumption
# by `apply.sh`.

cd ../infra

terraform fmt -recursive
terraform init
NEW_PLAN="./plans/$(date +%Y-%m-%d_%H-%M-%S).plan"
terraform plan -refresh=true -out=${NEW_PLAN} -input=false -var-file="./vars/vars.tfvars" 
