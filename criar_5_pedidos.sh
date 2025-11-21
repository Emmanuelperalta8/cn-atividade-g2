#!/bin/bash

set -e

echo "🍽️ Criando 5 pedidos no DynamoDB e enviando para SQS..."

QUEUE_URL="http://localhost:4566/000000000000/pedidos"
TABLE_NAME="Pedidos"

for i in {1..5}; do
  PEDIDO_ID="pedido-$i"
  CLIENTE="Cliente $i"

  echo ""
  echo "📦 Criando pedido $i:"
  echo "   ID     : $PEDIDO_ID"
  echo "   Cliente: $CLIENTE"

  # 1) Salvar no DynamoDB – chave primária: id
  awslocal dynamodb put-item \
    --table-name "$TABLE_NAME" \
    --item '{
      "id":        {"S": "'"$PEDIDO_ID"'"},
      "cliente":   {"S": "'"$CLIENTE"'"},
      "mesa":      {"N": "1"},
      "itens":     {"L": [{"S": "Pizza"}, {"S": "Refri"}]},
      "status":    {"S": "RECEBIDO"},
      "data_criacao": {"S": "2025-11-21T00:00:00Z"}
    }'

  # 2) Enviar mensagem para SQS com o mesmo id
  awslocal sqs send-message \
    --queue-url "$QUEUE_URL" \
    --message-body "{\"pedido_id\": \"${PEDIDO_ID}\"}" \
    >/dev/null

  echo "   ✅ Pedido salvo no DynamoDB e mensagem enviada à SQS"
done

echo ""
echo "✅ 5 pedidos criados com sucesso!"