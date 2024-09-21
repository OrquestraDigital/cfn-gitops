#!/bin/bash

# Esse script implanta os stacks CloudFormation contidos no diretorio $STACK_DIR que foram alterados no commit atual
# A implantação é feita utilizando o recurso ChangeSet, que permite atualizar um stack já existente
# Se o stack não existir, ele será criado. O nome do stack é obtido a partir do nome do arquivo CloudFormation.
# Os parâmetros do stack são obtidos a partir do arquivo de parâmetros JSON do stack que deve ter o mesmo nome do arquivo CloudFormation com a extensão .json. Exemplo:
#	stacks/
#		ec2-instance.yaml
#		ec2-instance.json
#		vpc.yaml
#		vpc.json
# O arquivo de parâmetros deve conter um objeto JSON com os parâmetros do stack. Exemplo:
#	{
#		"KeyName": "my-key",
#		"InstanceType": "t2.micro"
#	}
# O script verifica se o arquivo de parâmetros existe e, se não existir, utiliza um objeto vazio.

STACK_DIR="cloudformation/stacks"

# Função para criar ou atualizar um stack CloudFormation
deploy_stack() {

  local stack_file
  stack_file=$1

  local stack_name
  stack_name=$(basename "$stack_file" .yaml)

  local param_file
  param_file="${STACK_DIR}/${stack_name}.parameters.json"

  local change_set_name
  change_set_name="${stack_name}-changeset"

  # Verifica se o arquivo de parâmetros existe
  if [ -f "$param_file" ]; then
    params="--parameters file://${param_file}"
  else
    params=""
  fi

  # Cria um ChangeSet
  aws cloudformation create-change-set \
    --stack-name "$stack_name" \
    --template-body file://"$stack_file" \
    --change-set-name "$change_set_name" \
    "${params}" \
    --capabilities CAPABILITY_NAMED_IAM

  # Espera até que o ChangeSet esteja pronto
  aws cloudformation wait change-set-create-complete \
    --stack-name "$stack_name" \
    --change-set-name "$change_set_name"

  # Executa o ChangeSet
  aws cloudformation execute-change-set \
    --stack-name "$stack_name" \
    --change-set-name "$change_set_name"
}

# Obtém a lista de arquivos YAML alterados no commit atual
changed_files=$(git diff --name-only HEAD~1 HEAD | grep "${STACK_DIR}/.*\.yaml")

# Itera sobre os arquivos YAML alterados
for stack_file in $changed_files; do
  deploy_stack "$stack_file"
done