import json
import uuid
import boto3
import os
from datetime import datetime

# --- CONFIGURAÇÕES DE AMBIENTE ---
# O LocalStack usa o Account ID 000000000000 por padrão.
ENDPOINT = os.getenv("LOCALSTACK_ENDPOINT", "http://localhost:4566")
REGION = "us-east-1"
QUEUE_NAME = os.getenv("SQS_QUEUE_NAME", "pedidos")

# --- CLIENTES BOTO3 ---
# Passar o endpoint_url é crucial para o LocalStack
dynamodb = boto3.resource("dynamodb", endpoint_url=ENDPOINT, region_name=REGION)
sqs = boto3.client("sqs", endpoint_url=ENDPOINT, region_name=REGION)

TABLE = dynamodb.Table("Pedidos")

# Tenta obter a URL da fila dinamicamente (mais robusto)
try:
    response = sqs.get_queue_url(QueueName=QUEUE_NAME)
    QUEUE_URL = response['QueueUrl']
except Exception as e:
    # Fallback se a URL não puder ser obtida (usando o formato LocalStack)
    print(f"Aviso: Não foi possível obter QueueUrl dinamicamente. Usando fallback.")
    QUEUE_URL = f"{ENDPOINT}/000000000000/{QUEUE_NAME}"


def lambda_handler(event, context):
    try:
        body = json.loads(event["body"])
    except (TypeError, json.JSONDecodeError):
        return {"statusCode": 400, "body": json.dumps({"mensagem": "Requisição inválida."})}

    pedido_id = str(uuid.uuid4())

    item = {
        "id": pedido_id,
        "cliente": body.get("cliente", "Não informado"),
        "itens": body.get("itens", []),
        "status": "RECEBIDO",
        "data_criacao": datetime.utcnow().isoformat() + "Z",
    }
    
    # Lógica para evitar salvar 'None' no DynamoDB
    mesa = body.get("mesa")
    if mesa is not None:
        item["mesa"] = mesa

    # 1. Salvar no DynamoDB
    TABLE.put_item(Item=item)
    print(f"Pedido {pedido_id} salvo no DynamoDB.")

    # 2. Enviar ID do pedido para o SQS
    sqs.send_message(
        QueueUrl=QUEUE_URL,
        MessageBody=json.dumps({"pedido_id": pedido_id}),
    )
    print(f"ID do pedido {pedido_id} enviado para a fila SQS.")

    return {
        "statusCode": 201,
        "body": json.dumps(
            {
                "mensagem": "Pedido criado com sucesso! Em processamento.",
                "id": pedido_id,
            }
        ),
    }