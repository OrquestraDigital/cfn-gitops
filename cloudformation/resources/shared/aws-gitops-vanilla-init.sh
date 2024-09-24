#!/usr/bin/bash

# IMPORTANTE: Se você alterar o valor de TEMP_DIR, execute o comando .

export TEMP_DIR=".GITOPS_TEMP"
export GITOPS_S3_BUCKET=aws-gitops-vanilla
export GITOPS_S3_PREFIX=gitops
export GITOPS_CLOUDFORMATION_S3_PREFIX=${GITOPS_S3_PREFIX}/cloudformation
export STACK_DIR="cloudformation/stacks"
export TEMPLATE_DIR="cloudformation/templates"
export REPORT_DIR="${TEMP_DIR}/cfn-guard/reports"
export RULES_FILE_PATH="cloudformation/resources/cfn-guard/rules"
export RULES_SELECTED="cloudformation/resources/cfn-guard/selected_rules.txt"
export CODEBUILD_RESOURCES="cloudformation/resources/codebuild"

cd "$(git rev-parse --show-toplevel)" || exit 1
mkdir -p ${TEMP_DIR}