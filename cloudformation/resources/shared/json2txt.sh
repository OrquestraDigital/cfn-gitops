#!/bin/bash

# Verifica se o arquivo de entrada foi fornecido
if [ -z "$1" ]; then
  echo "Uso: $0 <arquivo.json>"
  exit 1
fi

# Define o arquivo de entrada e saída
input_file="$1"
output_file="${input_file%.json}.txt"

# Converte o JSON para texto
echo "Convertendo $input_file para $output_file..."

# Usa jq para formatar o JSON e awk para extrair o conteúdo
jq -r 'to_entries | .[] | "\(.key): \(.value)"' "$input_file" > "$output_file"

echo "Conversão concluída. O relatório de texto está em $output_file."
