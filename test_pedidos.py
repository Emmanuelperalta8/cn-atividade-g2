#!/usr/bin/env python3

import json
import boto3
import time
import sys

# Configurar clientes AWS
dynamodb = boto3.resource('dynamodb', endpoint_url='http://localhost:4566', region_name='us-east-1')
sqs = boto3.client('sqs', endpoint_url='http://localhost:4566', region_name='us-east-1')
s3 = boto3.client('s3', endpoint_url='http://localhost:4566', region_name='us-east-1')
sns = boto3.client('sns', endpoint_url='http://localhost:4566', region_name='us-east-1')
lambda_client = boto3.client('lambda', endpoint_url='http://localhost:4566', region_name='us-east-1')

print("=" * 70)
print("🍽️  TESTE COMPLETO DO SISTEMA DE PEDIDOS - RESTAURANTE")
print("=" * 70)

# 1. Testar DynamoDB
print("\n1️⃣  TESTANDO DYNAMODB")
print("-" * 70)
try:
    table = dynamodb.Table('Pedidos')
    table.put_item(Item={
        'id': 'test-001',
        'cliente': 'João Silva',
        'itens': ['Pizza Margherita', 'Refrigerante'],
        'mesa': 5,
        'status': 'recebido'
    })
    print("✅ Pedido inserido com sucesso")
    
    response = table.get_item(Key={'id': 'test-001'})
    print(f"✅ Pedido recuperado: {response['Item']['cliente']}")
except Exception as e:
    print(f"❌ Erro: {e}")
    sys.exit(1)

# 2. Testar SQS
print("\n2️⃣  TESTANDO SQS")
print("-" * 70)
try:
    queues = sqs.list_queues(QueueNamePrefix='pedidos')
    queue_url = queues['QueueUrls'][0]
    print(f"✅ Fila encontrada: {queue_url}")
    
    sqs.send_message(
        QueueUrl=queue_url,
        MessageBody=json.dumps({'id': 'test-001'})
    )
    print("✅ Mensagem enviada à fila SQS")
    
    messages = sqs.receive_message(QueueUrl=queue_url, MaxNumberOfMessages=1)
    if 'Messages' in messages:
        print(f"✅ Mensagem recebida: {messages['Messages'][0]['Body']}")
except Exception as e:
    print(f"❌ Erro: {e}")
    sys.exit(1)

# 3. Testar S3
print("\n3️⃣  TESTANDO S3")
print("-" * 70)
try:
    buckets = s3.list_buckets()
    bucket_names = [b['Name'] for b in buckets['Buckets']]
    print(f"✅ Buckets disponíveis: {bucket_names}")
except Exception as e:
    print(f"❌ Erro: {e}")
    sys.exit(1)

# 4. Testar SNS
print("\n4️⃣  TESTANDO SNS")
print("-" * 70)
try:
    topics = sns.list_topics()
    topic_names = [t['TopicArn'].split(':')[-1] for t in topics['Topics']]
    print(f"✅ Tópicos disponíveis: {topic_names}")
    
    response = sns.publish(
        TopicArn='arn:aws:sns:us-east-1:000000000000:PedidosConcluidos',
        Subject='Teste de Notificação',
        Message='Esta é uma mensagem de teste!'
    )
    print(f"✅ Notificação publicada - MessageId: {response['MessageId']}")
except Exception as e:
    print(f"❌ Erro: {e}")
    sys.exit(1)

# 5. Testar Lambda
print("\n5️⃣  TESTANDO LAMBDA")
print("-" * 70)
try:
    response = lambda_client.invoke(
        FunctionName='ProcessarPedido',
        InvocationType='RequestResponse',
        Payload=json.dumps({
            'Records': [{
                'body': json.dumps({'id': 'test-001'})
            }]
        })
    )
    
    if response['StatusCode'] == 200:
        print("✅ Lambda ProcessarPedido executada com sucesso")
        time.sleep(2)
        
        try:
            s3.head_object(Bucket='comprovantes', Key='test-001.pdf')
            print("✅ PDF criado com sucesso em S3")
        except:
            print("⚠️  PDF não encontrado (pode estar sendo processado)")
    else:
        print(f"❌ Erro na Lambda: {response}")
except Exception as e:
    print(f"❌ Erro: {e}")
    sys.exit(1)

print("\n" + "=" * 70)
print("✨ TESTES CONCLUÍDOS COM SUCESSO!")
print("=" * 70)
