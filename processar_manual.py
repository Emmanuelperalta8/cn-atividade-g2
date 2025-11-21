#!/usr/bin/env python3

import json
import boto3
import time
from lambdas.utils.gerar_pdf import gerar_pdf

dynamodb = boto3.resource('dynamodb', endpoint_url='http://localhost:4566', region_name='us-east-1')
s3 = boto3.client('s3', endpoint_url='http://localhost:4566', region_name='us-east-1')
sqs = boto3.client('sqs', endpoint_url='http://localhost:4566', region_name='us-east-1')

TABLE = dynamodb.Table('Pedidos')

def processar_pedidos():
    """Processa todos os pedidos com status RECEBIDO"""
    
    print("🔄 Iniciando processamento de pedidos...\n")
    
    # Buscar todos os pedidos com status RECEBIDO
    response = TABLE.scan(
        FilterExpression='#status = :status',
        ExpressionAttributeNames={'#status': 'status'},
        ExpressionAttributeValues={':status': 'RECEBIDO'}
    )
    
    pedidos = response.get('Items', [])
    print(f"📋 Encontrados {len(pedidos)} pedidos para processar\n")
    
    for pedido in pedidos:
        try:
            pedido_id = pedido['id']
            cliente = pedido['cliente']
            
            print(f"📦 Processando pedido de {cliente}...")
            
            # Gerar PDF
            pdf_bytes = gerar_pdf(pedido)
            print(f"  ✅ PDF gerado ({len(pdf_bytes)} bytes)")
            
            # Salvar no S3
            s3.put_object(
                Bucket='comprovantes',
                Key=f'{pedido_id}.pdf',
                Body=pdf_bytes,
                ContentType='application/pdf'
            )
            print(f"  ✅ PDF salvo em S3")
            
            # Atualizar status
            TABLE.update_item(
                Key={'id': pedido_id},
                UpdateExpression='SET #status = :status',
                ExpressionAttributeNames={'#status': 'status'},
                ExpressionAttributeValues={':status': 'PROCESSADO'}
            )
            print(f"  ✅ Status atualizado para PROCESSADO\n")
            
        except Exception as e:
            print(f"  ❌ Erro: {e}\n")

if __name__ == '__main__':
    # Processar a cada 5 segundos
    while True:
        processar_pedidos()
        print("⏳ Aguardando próxima verificação em 5 segundos...\n")
        time.sleep(5)

