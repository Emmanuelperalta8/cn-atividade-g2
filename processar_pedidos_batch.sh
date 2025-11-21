#!/bin/bash

set -e

echo "🔄 Processando todos os pedidos com status RECEBIDO usando a Lambda..."

python3 << 'PYTHON_EOF'
import boto3
import json

ENDPOINT = 'http://localhost:4566'
REGION = 'us-east-1'

dynamodb = boto3.resource('dynamodb', endpoint_url=ENDPOINT, region_name=REGION)
lambda_client = boto3.client('lambda', endpoint_url=ENDPOINT, region_name=REGION)

table = dynamodb.Table('Pedidos')

response = table.scan(
    FilterExpression='#status = :s',
    ExpressionAttributeNames={'#status': 'status'},
    ExpressionAttributeValues={':s': 'RECEBIDO'}
)

pedidos = response.get('Items', [])
print(f"📋 Encontrados {len(pedidos)} pedidos com status RECEBIDO.")

if not pedidos:
    exit(0)

for pedido in pedidos:
    pedido_id = pedido.get('id')
    if not pedido_id:
        continue

    print(f"\n🚀 Chamando Lambda ProcessarPedido para o pedido {pedido_id}...")

    event = {
        "Records": [
            {
                "body": json.dumps({"pedido_id": pedido_id})
            }
        ]
    }

    resp = lambda_client.invoke(
        FunctionName='ProcessarPedido',
        InvocationType='RequestResponse',
        Payload=json.dumps(event)
    )

    status = resp.get('StatusCode')
    print(f"   ✅ Status da invocação: {status}")
PYTHON_EOF

echo ""
echo "✅ Processamento via Lambda finalizado!"