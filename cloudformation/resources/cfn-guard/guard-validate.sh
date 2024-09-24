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
        echo "- [OK] Arquivo: $template - Regra: $rule_name"
        #rm "${report_file}"
        ;;
    19)
        echo "- [FALHA] Arquivo: $template - Regra: $rule_name"
        TEMPLATE_ERROR_COUNT=$((TEMPLATE_ERROR_COUNT + 1))
        ;;
    5)
        echo "- [FALHA] Arquivo: $template inválido"
        TEMPLATE_ERROR_COUNT=$((TEMPLATE_ERROR_COUNT + 1))
        ;;
    *)
        echo "- [FALHA] Erro desconhecido ao validar o arquivo $template ($EXIT_STATUS)"
        TEMPLATE_ERROR_COUNT=$((TEMPLATE_ERROR_COUNT + 1))
        ;;
    esac
}

function exit_with_error {
    echo "$1" 1>&2
    exit "$2"
}

# Redireciona todo o stdout para o arquivo


cd "$(git rev-parse --show-toplevel)" || exit_with_error "Erro ao mudar para o diretório raiz do repositorio" 13

# shellcheck source=/dev/null
source cloudformation/resources/shared/get_changed_files.sh "$1" || exit_with_error "Erro ao obter os arquivos alterados" 14

    OUTPUT_FILE="${TEMP_DIR}/validation_output.txt"
    exec > "$OUTPUT_FILE"

echo "VALIDAÇÃO COM O CFN-GUARD"

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

readarray -t CHANGED_FILES < "${TEMP_DIR}"/changed_files.txt || error_exit "Erro ao ler o arquivo changed_files.txt." 33

export -f validate_template
export REPORT_DIR
export TEMPLATE_ERROR_COUNT=0

for template in "${CHANGED_FILES[@]}"; do
    for rule in "${SELECTED_RULES[@]}"; do
        validate_template "$template" "$rule"
    done
done

echo $TEMPLATE_ERROR_COUNT > "${TEMP_DIR}"/validation_error_count.txt

# Mesclar todos os relatórios JUnit em um único arquivo
#report2junit ./cloudformation/resources/cfn-guard/reports/*  --destination-file ./cloudformation/resources/cfn-guard/reports/combined-junit-report.xml --ignore-failures
