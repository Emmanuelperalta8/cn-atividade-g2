#!/bin/bash

CLIENTE="$1"
ITENS="$2"
TEMPO="${3:-5}"

if [ -z "$CLIENTE" ] || [ -z "$ITENS" ]; then
  echo "Uso: $0 \"Nome do Cliente\" \"Item1,Item2\" [tempo_espera_segundos]"
  exit 1
fi

echo "📦 Criando pedido para: $CLIENTE"

PEDIDO_ID=$(uuidgen)

awslocal sqs send-message \
  --queue-url http://localhost:4566/000000000000/pedidos \
  --message-body "{\"pedido_id\": \"${PEDIDO_ID}\", \"cliente\": \"${CLIENTE}\", \"itens\": \"${ITENS}\"}"

echo "⏳ Pedido enviado: $PEDIDO_ID — aguardando $TEMPO segundos..."
sleep "$TEMPO"

echo "🔧 Processando pedido..."

PAYLOAD="{\"Records\":[{\"body\":\"{\\\"pedido_id\\\": \\\"${PEDIDO_ID}\\\"}\"}]}"

awslocal lambda invoke \
  --function-name ProcessarPedido \
  --payload "$PAYLOAD" \
  output.json >/dev/null

echo "📄 Verificando PDFs..."
awslocal s3 ls s3://comprovantes