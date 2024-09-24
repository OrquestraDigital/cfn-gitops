#!/bin/bash

function validate_template() {
    local template="$1"
    local rule="$2"
    local template_name
    local rule_name

    template_name=$(basename "$template") || error_exit "Erro ao obter o nome do template." 34
    rule_name=$(basename "$rule") || error_exit "Erro ao obter o nome da regra." 35

    report_file="${REPORT_DIR}"/"${template_name}"-"${rule_name}".xml
    cfn-guard validate -r "${rule}" -d "${template}" --type CFNTemplate --output-format junit --show-summary none --structured > "${report_file}"
    EXIT_STATUS=$?
    case $EXIT_STATUS in
    0)
        rm "${report_file}"
        ;;
    19)
        echo "O arquivo $template não está em conformidade com a regra $rule_name. Consulte o relatório de testes da compilação ${CODEBUILD_BUILD_ID} para obter mais detalhes."
        TEMPLATE_ERROR_COUNT=$((TEMPLATE_ERROR_COUNT + 1))
        ;;
    5)
        echo "Erro: O arquivo $template não é válido."
        TEMPLATE_ERROR_COUNT=$((TEMPLATE_ERROR_COUNT + 1))
        ;;
    *)
        echo "Erro: desconhecido ao validar o arquivo $template ($EXIT_STATUS)."
        TEMPLATE_ERROR_COUNT=$((TEMPLATE_ERROR_COUNT + 1))
        ;;
    esac
}

function exit_with_error {
    echo "$1" 1>&2
    exit "$2"
}

echo "Iniciando a validação dos templates CloudFormation com o cfn-guard..."

SCRIPT_DIR=$(dirname "$0") || exit_with_error "Erro ao obter o diretório do script." 12
cd "$SCRIPT_DIR" || exit_with_error "Erro ao mudar para o diretório do script." 12

cd "../../../" || exit_with_error "Erro ao mudar para o diretório inicial" 13

if [[ "${1}" != "--ci"  ]]; then
    # shellcheck source=/dev/null
    source aws-gitops-vanilla.env || exit_with_error "Erro ao carregar as variáveis de ambiente." 14
fi

if ! hash cfn-guard 2>/dev/null; then
    echo "cfn-guard não está instalado. Acesse o link https://docs.aws.amazon.com/cfn-guard/latest/ug/setting-up.html para instalar."
    error_exit "O cfn-guard não está instalado." 30
fi

# Excluir o diretório reports se ele existir
if [ -d "$REPORT_DIR" ]; then
    rm -rf "$REPORT_DIR" || error_exit "Erro ao excluir o diretório de relatórios." 32
fi

mkdir -p "$REPORT_DIR" || error_exit "Erro ao criar diretório de relatórios." 33

mapfile -t SELECTED_RULES <"${RULES_SELECTED}" || exit_with_error "Erro ao ler o arquivo de regras selecionadas." 33

#se CHANGED_FILES estiver vazio
if [[ ${#CHANGED_FILES[@]} -eq 0 && "${1}" != "--ci"  ]]; then

    if [[ "${1}" == "--git-compare" ]]; then
        # Obter os arquivos alterados no commit atual em comparação ao branch main
        mapfile -t temp_array < <(git diff --name-only main -- $(find ${STACK_DIR} -name '*.yaml'))
        CHANGED_FILES+=("${temp_array[@]}")
        mapfile -t temp_array < <(git diff --name-only main -- $(find ${TEMPLATE_DIR} -name '*.yaml'))
        CHANGED_FILES+=("${temp_array[@]}")
    else
        # Validar todos os templates
        mapfile -t temp_array < <(find "${STACK_DIR}" -name '*.yaml')
        CHANGED_FILES+=("${temp_array[@]}")
        mapfile -t temp_array < <(find "${TEMPLATE_DIR}" -name '*.yaml')
        CHANGED_FILES+=("${temp_array[@]}")
    fi

fi



export -f validate_template
export SCRIPT_DIR
export REPORT_DIR
export TEMPLATE_ERROR_COUNT=0

for template in "${CHANGED_FILES[@]}"; do
    for rule in "${SELECTED_RULES[@]}"; do
        validate_template "$template" "$rule"
    done
done

# Mesclar todos os relatórios JUnit em um único arquivo
#report2junit ./cloudformation/resources/cfn-guard/reports/*  --destination-file ./cloudformation/resources/cfn-guard/reports/combined-junit-report.xml --ignore-failures
