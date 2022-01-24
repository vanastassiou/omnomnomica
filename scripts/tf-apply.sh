#!/bin/env bash
#
# Applies most recent Terraform plan. You must run ./plan.sh first!

cd ../infra
LATEST_PLAN=$(ls plans/*.plan | sort -rn | head -1)
terraform apply -input=false "${LATEST_PLAN}"
