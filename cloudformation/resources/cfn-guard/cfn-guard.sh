#!/bin/bash

DEFAULT_RESET_RULES="N"
DEFAULT_KEEP_SELECTED_RULES="S"
DEFAULT_SELECT_MORE_RULES="S"
SCRIPT_DIR=$(dirname "$(realpath "$0")") || error_exit "Erro ao obter o diretório do script." 12
SELECTED_RULES_FILE="selected_rules.txt"
RULES_REGISTRY=$(curl -s https://api.github.com/repos/aws-cloudformation/aws-guard-rules-registry/releases/latest) || error_exit "Erro ao consultar a última release." 14
RULES_URL=$(echo "$RULES_REGISTRY" |
    grep "browser_download_url.*zip" |
    cut -d : -f 2,3 |
    tr -d \") || error_exit "Erro ao obter a URL das regras." 15
RULES_URL=$(echo "$RULES_URL" | tr -d ' ') || error_exit "Erro ao limpar a URL das regras." 17
RULES_VERSION=$(echo "$RULES_REGISTRY" |
    grep '"tag_name":' |
    cut -d '"' -f 4) || error_exit "Erro ao obter a versão da última release." 16
RULES_DIR="rules/aws-guard-rules-registry/${RULES_VERSION}"
TMP_DIR=$(mktemp -d) || error_exit "Erro ao criar diretório temporário." 18
RULES_FILE="${TMP_DIR}/aws-guard-rules.zip"

# Função para exibir mensagem de erro e sair com código de erro
function error_exit {
    echo "$1" 1>&2
    exit "$2"
}

# Função para solicitar entrada do usuário com valor padrão
function prompt_user {
    local prompt_message=$1
    local default_value=$2
    local user_input

    if [ "$NO_INTERACTION" == "true" ]; then
        echo "$default_value"
    else
        while true; do
            read -rp "$(echo -e "\n\n$prompt_message (S/N) [$default_value]: ")" user_input
            user_input=${user_input:-$default_value} # Define o valor padrão se a entrada estiver vazia
            if [[ "$user_input" == "S" || "$user_input" == "N" ]]; then
                echo "$user_input"
                break
            else
                echo "Entrada inválida. Por favor, digite 'S' para Sim ou 'N' para Não."
            fi
        done
    fi
}

# Verificar se o parâmetro --no-interaction foi passado
NO_INTERACTION="false"
for arg in "$@"; do
    case $arg in
    --no-interaction)
        NO_INTERACTION="true"
        shift
        ;;
    esac
done

# Mensagem inicial informando os parâmetros aceitos e possíveis mensagens de erro
if [ "$NO_INTERACTION" != "true" ]; then
    cat <<EOF
Parâmetros aceitos:
  --no-interaction: Executa o script sem interação com o usuário, usando valores padrão.
Possíveis mensagens de erro:
  12: Erro ao obter o diretório do script.
  13: Erro ao mudar para o diretório do script.
  14: Erro ao consultar a última release.
  15: Erro ao obter a URL das regras.
  16: Erro ao obter a versão da última release.
  17: Erro ao limpar a URL das regras.
  18: Erro ao criar diretório temporário.
  19: Erro ao baixar as regras.
  20: Erro ao criar backup do diretório de regras.
  21: Erro ao remover o diretório de regras existente.
  22: Erro ao criar diretório de regras.
  23: Erro ao descompactar as regras.
  24: Erro ao copiar as regras para o diretório.
  25: Erro ao remover o arquivo de regras baixado.
  26: Erro ao remover o diretório temporário.
  27: Erro ao listar as regras disponíveis.
  28: Erro ao remover o arquivo de regras selecionadas.
  29: Erro ao adicionar regra ao arquivo de regras selecionadas.
  30: O cfn-guard não está instalado.
  33: Erro ao criar diretório de relatórios.
  34: Erro ao obter o nome do template.
  35: Erro ao obter o nome da regra.
  36: A regra não foi encontrada.
  37: O arquivo baixado não é um arquivo zip válido.
  38: Erro ao descompactar o arquivo zip.

Pressione qualquer tecla para continuar...
EOF
    read -n 1 -s -r
fi

cd "$SCRIPT_DIR" || error_exit "Erro ao mudar para o diretório do script." 13

wget -q "$RULES_URL" -O "$RULES_FILE" || error_exit "Erro ao baixar as regras." 19

# Verificar se o arquivo baixado é um arquivo zip válido
if file "$RULES_FILE" | grep -q 'Zip archive data'; then

    # Verificar se o diretório de regras já existe
    if [ -d "$RULES_DIR" ]; then
        REPLY=$(prompt_user "A versão atual das regras já é a $RULES_VERSION. Deseja reinicializar?" "$DEFAULT_RESET_RULES")
        if [ "$REPLY" == "S" ]; then
            # Criar um backup do diretório existente
            BACKUP_FILE="${RULES_DIR}-$(date +%Y-%m-%d).old"
            echo "Criando backup do diretório de regras existente em $BACKUP_FILE..."
            zip -r "$BACKUP_FILE" "$RULES_DIR" || error_exit "Erro ao criar backup do diretório de regras." 20
            # Remover o diretório existente
            rm -rf "$RULES_DIR" || error_exit "Erro ao remover o diretório de regras existente." 21
        else
            echo "O diretório de regras já existe. As regras existentes serão mantidas. A atualização foi cancelada."
            exit 0
        fi
    fi

    mkdir -p "$RULES_DIR" || error_exit "Erro ao criar diretório de regras." 22
    unzip -j -o "$RULES_FILE" -d "$TMP_DIR" || error_exit "Erro ao descompactar as regras." 23
    cp "${TMP_DIR}"/*.guard "${RULES_DIR}" || error_exit "Erro ao copiar as regras para o diretório." 24
    rm "${RULES_FILE}" || error_exit "Erro ao remover o arquivo de regras baixado." 25
    rm -rf "${TMP_DIR}" || error_exit "Erro ao remover o diretório temporário." 26
    echo "Regras atualizadas com sucesso."

    # Listar todas as regras disponíveis
    mapfile -t RULES_LIST < <(find "$RULES_DIR" -type f -name "*.guard") || error_exit "Erro ao listar as regras disponíveis." 27

    # Verificar se o arquivo de regras selecionadas existe
    if [ -f "$SELECTED_RULES_FILE" ]; then
        echo -e "\n\nArquivo de regras selecionado anteriormente:"
        cat "$SELECTED_RULES_FILE"
        KEEP_SELECTED_RULES=$(prompt_user "Deseja manter?" "$DEFAULT_KEEP_SELECTED_RULES")
        if [ "$KEEP_SELECTED_RULES" != "S" ]; then
            rm "$SELECTED_RULES_FILE" || error_exit "Erro ao remover o arquivo de regras selecionadas." 28
        fi
    fi

    # Se o arquivo de regras selecionadas não existir, solicitar ao usuário para selecionar as regras
    if [ ! -f "$SELECTED_RULES_FILE" ]; then
        echo -e "\n\nSelecione o arquivo de regras que deseja utilizar:"
        select rule in "${RULES_LIST[@]}"; do
            echo "$rule" >>"$SELECTED_RULES_FILE" || error_exit "Erro ao adicionar regra ao arquivo de regras selecionadas." 29
            MORE_RULES=$(prompt_user "Deseja selecionar mais regras?" "$DEFAULT_SELECT_MORE_RULES")
            if [ "$MORE_RULES" != "S" ]; then
                break
            fi
        done
    fi

else
    error_exit "O arquivo baixado não é um arquivo zip válido." 37
fi
