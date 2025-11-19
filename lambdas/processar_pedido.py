import json
import boto3
from utils.gerar_pdf import gerar_comprovante_pdf

sqs = boto3.client('sqs', endpoint_url='http://localhost:4566', region_name='us-east-1')  # ← ADICIONAR region_name
s3 = boto3.client('s3', endpoint_url='http://localhost:4566', region_name='us-east-1')    # ← ADICIONAR region_name
dynamodb = boto3.resource('dynamodb', endpoint_url='http://localhost:4566', region_name='us-east-1')  # ← ADICIONAR region_name
sns = boto3.client('sns', endpoint_url='http://localhost:4566', region_name='us-east-1')  # ← ADICIONAR region_name

def lambda_handler(event, context):
    """
    Processa pedidos da fila SQS:
    1. Recupera dados do pedido no DynamoDB
    2. Gera comprovante em PDF
    3. Salva PDF no S3
    4. Publica notificação no SNS
    """
    
    try:
        for record in event['Records']:
            # Extrair ID do pedido da mensagem SQS
            pedido = json.loads(record['body'])
            pedido_id = pedido['id']
            
            print(f"Processando pedido: {pedido_id}")
            
            # Recuperar dados do pedido no DynamoDB
            table = dynamodb.Table('Pedidos')
            response = table.get_item(Key={'id': pedido_id})
            
            if 'Item' not in response:
                print(f"Pedido {pedido_id} não encontrado!")
                continue
            
            dados = response['Item']
            
            # Gerar comprovante em PDF
            pdf_bytes = gerar_comprovante_pdf(dados)
            
            # Salvar PDF no S3
            s3.put_object(
                Bucket='comprovantes',
                Key=f'{pedido_id}.pdf',
                Body=pdf_bytes,
                ContentType='application/pdf'
            )
            print(f"PDF salvo em S3: s3://comprovantes/{pedido_id}.pdf")
            
            # Atualizar status do pedido no DynamoDB
            table.update_item(
                Key={'id': pedido_id},
                UpdateExpression='SET #status = :status',
                ExpressionAttributeNames={'#status': 'status'},
                ExpressionAttributeValues={':status': 'processado'}
            )
            
            # Publicar notificação no SNS
            sns.publish(
                TopicArn='arn:aws:sns:us-east-1:000000000000:PedidosConcluidos',
                Subject='Pedido Pronto',
                Message=f"O pedido {pedido_id} do cliente {dados.get('cliente', 'N/A')} foi concluído!"
            )
            print(f"Notificação enviada para pedido {pedido_id}")
        
        return {
            'statusCode': 200,
            'body': json.dumps('Pedidos processados com sucesso')
        }
    
    except Exception as e:
        print(f"Erro ao processar pedido: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Erro: {str(e)}')
        }