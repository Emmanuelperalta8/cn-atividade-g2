import json
import boto3
import uuid

dynamodb = boto3.resource('dynamodb', endpoint_url='http://localhost:4566')
sqs = boto3.client('sqs', endpoint_url='http://localhost:4566')

def lambda_handler(event, context):
    body = json.loads(event['body'])
    pedido_id = str(uuid.uuid4())

    item = {
        'id': pedido_id,
        'cliente': body['cliente'],
        'itens': body['itens'],
        'mesa': body['mesa'],
        'status': 'recebido'
    }

    table = dynamodb.Table('Pedidos')
    table.put_item(Item=item)

    sqs.send_message(
        QueueUrl='http://localhost:4566/000000000000/pedidos',
        MessageBody=json.dumps({'id': pedido_id})
    )

    return {
        'statusCode': 200,
        'body': json.dumps({'pedido_id': pedido_id})
    }
