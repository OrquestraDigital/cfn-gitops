#!/bin/bash

# Função para ler entrada do usuário com valor padrão
read_input() {
	local prompt="$1"
	local default="$2"
	local input
	read -rp "$prompt" input
	echo "${input:-$default}"
}

# Solicitar informações do usuário
repository_name=$(read_input "Digite o nome do repositório CodeCommit para GitOps (aws-gitops-vanilla): " "aws-gitops-vanilla")
s3_bucket=$(read_input "Digite o nome do bucket S3 para suporte ao GitOps (aws-gitops-vanilla): " "aws-gitops-vanilla")
s3_key=$(read_input "Digite o caminho do arquivo zip de inicialização do repositorio para GitOps que será gerado no bucket S3 de suporte ao GitOps (aws-gitops-vanilla/): " "aws-gitops-vanilla/")
stack_name=$(read_input "Digite o nome do stack CloudFormation da automação GitOps (aws-gitops-vanilla): " "aws-gitops-vanilla")


cd "$(git rev-parse --show-toplevel)" || exit 1

# Verifica se o arquivo .gitignore existe
if [ ! -f .gitignore ]; then
    echo "Arquivo .gitignore não encontrado."
    exit 1
fi

# Lê o conteúdo do .gitignore linha a linha
while IFS= read -r line; do
    # Ignora linhas vazias ou que começam com # (comentários)
    if [[ -z "$line" || "$line" =~ ^# ]]; then
        continue
    fi

    # Verifica se o padrão termina com *, indicando um diretório
    if [[ "$line" =~ \*$ ]]; then
        # Remove o asterisco para a busca
        pattern="${line%*}"
        find . -wholename "$pattern" -type d -print0 | xargs -0 rm -rf
    else
        # Busca por arquivos
        find . -name "$line" -print0 | xargs -0 rm -f
    fi
done < .gitignore

# Verificar se o bucket S3 existe
if aws s3 ls "s3://$s3_bucket" 2>&1 | grep -q 'NoSuchBucket'; then

	echo "Bucket $s3_bucket não existe. Criando o bucket..."

	aws cloudformation deploy \
		--template-file "../../templates/S3/S3Bucket.yaml" \
		--stack-name "$stack_name"-base \
		--parameter-overrides BucketName="$s3_bucket" \
		--capabilities CAPABILITY_NAMED_IAM

else
	echo "Bucket $s3_bucket já existe."
fi

zip_file="repository_files.zip"
zip -r "$zip_file" \
	cloudformation/ \
	.gitignore \
	README.md

# Enviar o arquivo zip para o bucket S3
aws s3 cp "$zip_file" s3://"$s3_bucket"/"$s3_key"

rm "$zip_file"

cd - || true

aws cloudformation deploy \
	--template-file "aws.gitops.vanilla.main.yaml" \
	--stack-name "$stack_name" \
	--parameter-overrides RepositoryName="$repository_name" S3Bucket="$s3_bucket" S3Key="${s3_key}repository_files.zip" \
	--capabilities CAPABILITY_NAMED_IAM

echo "Script executado com sucesso!"
