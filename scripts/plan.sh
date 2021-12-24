#!/bin/bash
#
# Runs `terraform plan` and outputs the plan to a file for later consumption
# by `apply.sh`.

cd ../infra

terraform fmt -recursive
terraform init
terraform plan -refresh=true -out=$(date +%Y-%m-%d_%H-%M-%S).plan -input=false -var-file="dev.tfvars" 
