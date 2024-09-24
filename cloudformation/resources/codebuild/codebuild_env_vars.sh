#!/usr/bin/env bash

# Nome do projeto CodeBuild
PROJECT_NAME="aws-gitops-vanilla-prvalidate"

# Obter o ID da última execução do build
LAST_BUILD_ID=$(aws codebuild list-builds-for-project --project-name "$PROJECT_NAME" --sort-order DESCENDING --query 'ids[0]' --output text)

# Verificar se o ID foi obtido com sucesso
if [ -z "$LAST_BUILD_ID" ]; then
    echo "Erro: Não foi possível obter o ID da última execução do build."
    exit 1
fi

# Obter as variáveis de ambiente da última execução do build
ENV_VARS=$(aws codebuild batch-get-builds --ids "$LAST_BUILD_ID" --query 'builds[0].environment.environmentVariables' --output json)

# Verificar se as variáveis de ambiente foram obtidas com sucesso
if [ -z "$ENV_VARS" ]; then
    echo "Erro: Não foi possível obter as variáveis de ambiente da última execução do build."
    exit 1
fi

# Exportar as variáveis de ambiente
echo "$ENV_VARS" | jq -r '.[] | "export \(.name)=\(.value)"' > /tmp/codebuild_env_vars.sh
echo "$ENV_VARS" | jq -r '.[] | "\(.name)=\(.value)"' > codebuild.env

source /tmp/codebuild_env_vars.sh

cat /tmp/codebuild_env_vars.sh

# Remover o arquivo temporário
rm /tmp/codebuild_env_vars.sh

# Agora você pode usar as variáveis de ambiente no seu script
echo -e "\nVariáveis de ambiente da última execução do build foram exportadas com sucesso."
