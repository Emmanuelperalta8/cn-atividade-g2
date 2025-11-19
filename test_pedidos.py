#!/usr/bin/env python3

import json
import boto3
import time
from datetime import datetime

# Configurar clientes AWS
dynamodb = boto3.resource('dynamodb', endpoint_url='http://localhost:4566', region_name='us-east-1')
sqs = boto3.client('sqs', endpoint_url='http://localhost:4566', region_name='us-east-1')
s3 = boto3.client('s3', endpoint_url='http://localhost:4566', region_name='us-east-1')
sns = boto3.client('sns', endpoint_url='http://localhost:4566', region_name='us-east-1')
lambda_client = boto3.client('lambda', endpoint_url='http://localhost:4566', region_name='us-east-1')

print("=" * 60)
print("🍽️  TESTE DO SISTEMA DE PEDIDOS - RESTAURANTE")
print("=" * 60)

# 1. Testar DynamoDB
print("\n1️⃣  TESTANDO DYNAMODB")
print("-" * 60)
try:
    table = dynamodb.Table('Pedidos')
    table.put_item(Item={
        'id': 'test-123',
        'cliente': 'João Silva',
        'itens': ['Pizza Margherita', 'Refrigerante'],
        'mesa': 5,
        'status': 'recebido'
    })
    print("✅ Pedido inserido com sucesso")
    
    response = table.get_item(Key={'id': 'test-123'})
    print(f"✅ Pedido recuperado: {response['Item']['cliente']}")
except Exception as e:
    print(f"❌ Erro: {e}")

# 2. Testar SQS
print("\n2️⃣  TESTANDO SQS")
print("-" * 60)
try:
    # Obter URL da fila
    queues = sqs.list_queues(QueueNamePrefix='pedidos')
    queue_url = queues['QueueUrls'][0]
    print(f"✅ Fila encontrada: {queue_url}")
    
    # Enviar mensagem
    sqs.send_message(
        QueueUrl=queue_url,
        MessageBody=json.dumps({'id': 'test-123'})
    )
    print("✅ Mensagem enviada à fila")
    
    # Receber mensagem
    messages = sqs.receive_message(QueueUrl=queue_url, MaxNumberOfMessages=1)
    if 'Messages' in messages:
        print(f"✅ Mensagem recebida: {messages['Messages'][0]['Body']}")
except Exception as e:
    print(f"❌ Erro: {e}")

# 3. Testar S3
print("\n3️⃣  TESTANDO S3")
print("-" * 60)
try:
    # Listar buckets
    buckets = s3.list_buckets()
    print(f"✅ Buckets disponíveis: {[b['Name'] for b in buckets['Buckets']]}")
except Exception as e:
    print(f"❌ Erro: {e}")

# 4. Testar SNS
print("\n4️⃣  TESTANDO SNS")
print("-" * 60)
try:
    topics = sns.list_topics()
    print(f"✅ Tópicos disponíveis: {[t['TopicArn'].split(':')[-1] for t in topics['Topics']]}")
    
    # Publicar mensagem
    sns.publish(
        TopicArn='arn:aws:sns:us-east-1:000000000000:PedidosConcluidos',
        Subject='Teste',
        Message='Mensagem de teste'
    )
    print("✅ Notificação publicada")
except Exception as e:
    print(f"❌ Erro: {e}")

# 5. Testar Lambda
print("\n5️⃣  TESTANDO LAMBDA")
print("-" * 60)
try:
    # Invocar Lambda de processar pedido
    response = lambda_client.invoke(
        FunctionName='ProcessarPedido',
        InvocationType='RequestResponse',
        Payload=json.dumps({
            'Records': [{
                'body': json.dumps({'id': 'test-123'})
            }]
        })
    )
    
    if response['StatusCode'] == 200:
        print("✅ Lambda ProcessarPedido executada com sucesso")
        
        # Verificar se PDF foi criado
        try:
            s3.head_object(Bucket='comprovantes', Key='test-123.pdf')
            print("✅ PDF criado com sucesso em S3")
        except:
            print("⚠️  PDF não encontrado em S3")
    else:
        print(f"❌ Erro na Lambda: {response}")
except Exception as e:
    print(f"❌ Erro: {e}")

print("\n" + "=" * 60)
print("✨ TESTES CONCLUÍDOS")
print("=" * 60)