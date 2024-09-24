#!/bin/bash

# Verifique se o arquivo de entrada foi fornecido
if [ -z "$1" ]; then
  echo "Uso: $0 arquivo_junit.xml"
  exit 1
fi

# Arquivo de entrada e saída
input_file="$1"
output_file="${input_file%.xml}.txt"

# Inicie o arquivo de texto
echo "Relatório de Testes JUnit" > "$output_file"

# Extraia informações do arquivo JUnit XML e converta para texto
awk '
BEGIN {
  print "Resumo dos Testes\n"
}
/<testsuite/ {
  match($0, /name="([^"]*)"/, suite_name)
  match($0, /tests="([^"]*)"/, total_tests)
  match($0, /failures="([^"]*)"/, failures)
  match($0, /errors="([^"]*)"/, errors)
  printf "Suite: %s\nTotal de Testes: %s\nFalhas: %s\nErros: %s\n\n", suite_name[1], total_tests[1], failures[1], errors[1]
}
/<testcase/ {
  match($0, /name="([^"]*)"/, test_name)
  printf "- Teste: %s\n", test_name[1]
}
/<failure/ {
  match($0, /message="([^"]*)"/, failure_message)
  printf "  - Falha: %s\n", failure_message[1]
}
' "$input_file" >> "$output_file"

echo "Conversão concluída. Arquivo de texto gerado: $output_file"
