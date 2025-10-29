import boto3
import json
from utils.gerar_pdf import gerar_comprovante_pdf

sqs = boto3.client('sqs', endpoint_url='http://localhost:4566')
s3 = boto3.client('s3', endpoint_url='http://localhost:4566')
dynamodb = boto3.resource('dynamodb', endpoint_url='http://localhost:4566')

def lambda_handler(event, context):
    for record in event['Records']:
        pedido = json.loads(record['body'])
        pedido_id = pedido['id']

        table = dynamodb.Table('Pedidos')
        response = table.get_item(Key={'id': pedido_id})
        dados = response['Item']

        pdf_bytes = gerar_comprovante_pdf(dados)

        s3.put_object(
            Bucket='comprovantes',
            Key=f'{pedido_id}.pdf',
            Body=pdf_bytes,
            ContentType='application/pdf'
        )
