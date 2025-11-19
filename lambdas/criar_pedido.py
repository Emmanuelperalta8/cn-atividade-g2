import json
import boto3
import uuid

dynamodb = boto3.resource('dynamodb', endpoint_url='http://localhost:4566', region_name='us-east-1')
sqs = boto3.client('sqs', endpoint_url='http://localhost:4566', region_name='us-east-1')

def lambda_handler(event, context):
    """
    Cria um novo pedido:
    1. Valida os dados de entrada
    2. Salva no DynamoDB
    3. Envia para fila SQS
    """
    
    try:
        # Parse do corpo da requisição
        body = json.loads(event['body'])
        
        # Validação dos campos obrigatórios
        if not all(key in body for key in ['cliente', 'itens', 'mesa']):
            return {
                'statusCode': 400,
                'body': json.dumps({'erro': 'Campos obrigatórios: cliente, itens, mesa'})
            }
        
        # Gerar ID único do pedido
        pedido_id = str(uuid.uuid4())
        
        # Preparar item para DynamoDB
        item = {
            'id': pedido_id,
            'cliente': body['cliente'],
            'itens': body['itens'],
            'mesa': body['mesa'],
            'status': 'recebido'
        }
        
        # Salvar no DynamoDB
        table = dynamodb.Table('Pedidos')
        table.put_item(Item=item)
        print(f"Pedido {pedido_id} salvo no DynamoDB")
        
        # Enviar para fila SQS
        sqs.send_message(
            QueueUrl='http://localhost:4566/000000000000/pedidos',
            MessageBody=json.dumps({'id': pedido_id})
        )
        print(f"Pedido {pedido_id} enviado para fila SQS")
        
        # Retornar sucesso
        return {
            'statusCode': 200,
            'body': json.dumps({
                'mensagem': 'Pedido criado com sucesso',
                'pedido_id': pedido_id
            })
        }
    
    except json.JSONDecodeError:
        return {
            'statusCode': 400,
            'body': json.dumps({'erro': 'JSON inválido'})
        }
    except Exception as e:
        print(f"Erro ao criar pedido: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'erro': str(e)})
        }