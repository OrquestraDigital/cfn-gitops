#!/usr/bin/bash

cd "$(git rev-parse --show-toplevel)" || exit 1
# shellcheck source=/dev/null
source ./cloudformation/resources/shared/aws-gitops-vanilla-init.sh

if [[ ! -f "${TEMP_DIR}"/changed_files.txt ]]; then

    if [[ "${1}" == "--git-compare" ]]; then
        # Obter os arquivos alterados no commit atual em comparação ao branch main
        # shellcheck disable=SC2046
        mapfile -t temp_array < <(git diff --name-only main -- $(find "${STACK_DIR}" -name *.yaml))
        CHANGED_FILES+=("${temp_array[@]}")
        # shellcheck disable=SC2046
        mapfile -t temp_array < <(git diff --name-only main -- $(find "${TEMPLATE_DIR}" -name *.yaml))
        CHANGED_FILES+=("${temp_array[@]}")
    else
        # Validar todos os templates
        mapfile -t temp_array < <(find "${STACK_DIR}" -name '*.yaml')
        CHANGED_FILES+=("${temp_array[@]}")
        mapfile -t temp_array < <(find "${TEMPLATE_DIR}" -name '*.yaml')
        CHANGED_FILES+=("${temp_array[@]}")
    fi

    #Salvar em um arquivo
    printf "%s\n" "${CHANGED_FILES[@]}" > "${TEMP_DIR}"/changed_files.txt

fi
