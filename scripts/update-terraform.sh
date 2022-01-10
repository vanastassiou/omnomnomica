#!/bin/env bash
#
# Installs Terraform's latest version
# Updates existing installation if already installed

declare TF_CURRENT_VERSION

if $(which terraform); then
    TF_CURRENT_VERSION=$(terraform --version | head -n 1 | sed -n 's/Terraform v//p') # Prints only digits of currently installed version number
else
    TF_CURRENT_VERSION=""
fi

declare TF_LATEST_VERSION
TF_LATEST_VERSION=$(curl -s https://github.com/hashicorp/terraform/releases/latest | grep -o -P '(?<=tag/v).*(?=">redirected)') # Extracts newest version from redirect URL

mkdir ./terraform-temp
wget -q "https://releases.hashicorp.com/terraform/${TF_LATEST_VERSION}/terraform_${TF_LATEST_VERSION}_linux_amd64.zip" -O "./terraform-temp/terraform.zip"
unzip -o -q "./terraform-temp/terraform.zip" -d "./terraform-temp"
rm -f "./terraform-temp/terraform.zip"
sudo mv -f "./terraform-temp/terraform" "/usr/bin/terraform"
rm -rf "./terraform-temp"

echo "Installed $(terraform --version | head -n 1)"
