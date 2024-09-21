#!/usr/bin/env bash

function validate_template() {
    local template="$1"
    local rule="$2"
    local TEMPLATE_NAME
    local RULE_NAME
    TEMPLATE_NAME=$(basename "$template") || error_exit "Erro ao obter o nome do template." 34
    RULE_NAME=$(basename "$rule") || error_exit "Erro ao obter o nome da regra." 35

    TEMPLATE_NAME=$(basename "$template") || exit_with_error "Erro ao obter o nome do template." 34
    RULE_NAME=$(basename "$rule") || exit_with_error "Erro ao obter o nome da regra." 35

    cfn-guard validate -r "${rule}" -d "${template}" --type CFNTemplate --output-format junit --show-summary none --structured > "${REPORT_DIR}"/"${TEMPLATE_NAME}"-"${RULE_NAME}".xml
    EXIT_STATUS=$?
    case $EXIT_STATUS in
    0)
        post_comment_to_pr "O arquivo $TEMPLATE_NAME está em conformidade com a regra $RULE_NAME." "${template}" "${template}"
        ;;
    19)
        post_comment_to_pr "O arquivo $TEMPLATE_NAME não está em conformidade com a regra $RULE_NAME. Consulte o relatório em ${REPORT_DIR} para obter mais detalhes." "${template}"
        ;;
    5)
        post_comment_to_pr "Erro: O arquivo $TEMPLATE_NAME não é válido." "${template}"
        ;;
    *)
        post_comment_to_pr "Erro desconhecido ao validar o arquivo $TEMPLATE_NAME ($EXIT_STATUS)." "${template}"
        ;;
    esac
}

function post_comment_to_pr {
    local file_path="$2"

    if [[ ! -f "$file_path" ]]; then
        echo "File not found: $file_path"
        return 1
    fi

    echo "Posting comment to PR with the following details:"
    echo "Repository Name: ${CI_REPOSITORY_NAME}"
    echo "Before Commit ID: ${CI_SOURCE_COMMIT}"
    echo "After Commit ID: ${CI_DESTINATION_COMMIT}"
    echo "Client Request Token: $(uuidgen)"
    echo "Content: ${COMMENT_CONTENT}"
    echo "File Path: ${file_path}"

    if [[ "$IS_GIT_COMPARE" == true ]]; then
        COMMENT_CONTENT="Error occurred during validation"
        echo "Posting error comment to PR with the following details:"
        echo "Repository Name: ${CI_REPOSITORY_NAME}"
        echo "Before Commit ID: ${CI_SOURCE_COMMIT}"
        echo "After Commit ID: ${CI_DESTINATION_COMMIT}"
        echo "Client Request Token: $(uuidgen)"
        echo "Content: ${COMMENT_CONTENT}"
        echo "File Path: ${file_path}"

        POST_RESULT=$(aws codecommit post-comment-for-compared-commit \
                --repository-name "${CI_REPOSITORY_NAME}" \
                --before-commit-id "${CI_SOURCE_COMMIT}" \
                --after-commit-id "${CI_DESTINATION_COMMIT}" \
                --client-request-token "$(uuidgen)" \
                --content "${COMMENT_CONTENT}" \
                --location filePath="${file_path}",filePosition=1,relativeFileVersion=AFTER \
                )
        echo "$POST_RESULT"

    fi
}

function exit_with_error {
    echo "$1" 1>&2
    exit "$2"
}


echo "Iniciando a validação dos templates CloudFormation com o cfn-guard..."

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd) || exit_with_error "Erro ao obter o diretório do script." 12
cd "$SCRIPT_DIR" || exit_with_error "Erro ao mudar para o diretório do script." 12
cd "../../../" || exit_with_error "Erro ao mudar para o diretório inicial" 13

source aws-gitops-vanilla.env || exit_with_error "Erro ao carregar as variáveis de ambiente." 14
if ! hash cfn-guard 2>/dev/null; then
    echo "cfn-guard não está instalado. Acesse o link https://docs.aws.amazon.com/cfn-guard/latest/ug/setting-up.html para instalar."
    error_exit "O cfn-guard não está instalado." 30
fi

# Validar usando as regras selecionadas
export STACK_DIR="./cloudformation/stacks"
export REPORT_DIR="cloudformation/resources/cfn-guard/reports"
export TEMPLATE_DIR="./cloudformation/templates"

# Excluir o diretório reports se ele existir
if [ -d "$REPORT_DIR" ]; then
    rm -rf "$REPORT_DIR" || error_exit "Erro ao excluir o diretório de relatórios." 32
fi

mkdir -p "$REPORT_DIR" || error_exit "Erro ao criar diretório de relatórios." 33

mapfile -t SELECTED_RULES <"${RULES_SELECTED}" || exit_with_error "Erro ao ler o arquivo de regras selecionadas." 33

# Inicializar o array CHANGED_FILES
CHANGED_FILES=()

# Verificar se o parâmetro --no-interaction foi fornecido
IS_GIT_COMPARE=false
if [[ "$1" == "--git-compare" ]]; then
    IS_GIT_COMPARE=true
    # Obter os arquivos alterados no commit atual em comparação ao branch main
    mapfile -t temp_array < <(git diff --name-only main -- $(find ${STACK_DIR} -name '*.yaml'))
    CHANGED_FILES+=("${temp_array[@]}")
    mapfile -t temp_array < <(git diff --name-only main -- $(find ${TEMPLATE_DIR} -name '*.yaml'))
    CHANGED_FILES+=("${temp_array[@]}")
else
    # Validar todos os templates
    if compgen -G "${STACK_DIR}/**/*.yaml" > /dev/null; then
        mapfile -t temp_array < <(find "${STACK_DIR}" -name '*.yaml')
        CHANGED_FILES+=("${temp_array[@]}")
    fi
    if compgen -G "${TEMPLATE_DIR}/**/*.yaml" > /dev/null; then
        mapfile -t temp_array < <(find "${TEMPLATE_DIR}" -name '*.yaml')
        CHANGED_FILES+=("${temp_array[@]}")
    fi
fi

export IS_GIT_COMPARE
export -f validate_template
export -f post_comment_to_pr
export SCRIPT_DIR
export REPORT_DIR

for template in "${CHANGED_FILES[@]}"; do
    TEMPLATE_NAME=$(basename "$template") || error_exit "Erro ao obter o nome do template." 34
    echo "Validando o $TEMPLATE_NAME ..."
    for rule in "${SELECTED_RULES[@]}"; do
        bash -c "validate_template '$template' '$rule'"
    done
done

# Mesclar todos os relatórios JUnit em um único arquivo
#report2junit ./cloudformation/resources/cfn-guard/reports/*  --destination-file ./cloudformation/resources/cfn-guard/reports/combined-junit-report.xml --ignore-failures