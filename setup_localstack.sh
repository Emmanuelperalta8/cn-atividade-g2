#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🚀 Iniciando setup do LocalStack...${NC}\n"

# 1. Criar tabela DynamoDB
echo -e "${YELLOW}1️⃣  Criando tabela DynamoDB 'Pedidos'...${NC}"
awslocal dynamodb create-table \
  --table-name Pedidos \
  --attribute-definitions \
    AttributeName=id,AttributeType=S \
  --key-schema \
    AttributeName=id,KeyType=HASH \
  --provisioned-throughput \
    ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-east-1 2>/dev/null

echo -e "${GREEN}✅ Tabela DynamoDB criada!${NC}\n"

# 2. Criar fila SQS
echo -e "${YELLOW}2️⃣  Criando fila SQS 'pedidos'...${NC}"
QUEUE_URL=$(awslocal sqs create-queue --queue-name pedidos --region us-east-1 | grep QueueUrl | cut -d'"' -f4)
echo -e "${GREEN}✅ Fila SQS criada: $QUEUE_URL${NC}\n"

# 3. Criar bucket S3
echo -e "${YELLOW}3️⃣  Criando bucket S3 'comprovantes'...${NC}"
awslocal s3 mb s3://comprovantes --region us-east-1 2>/dev/null
echo -e "${GREEN}✅ Bucket S3 criado!${NC}\n"

# 4. Criar tópico SNS
echo -e "${YELLOW}4️⃣  Criando tópico SNS 'PedidosConcluidos'...${NC}"
SNS_TOPIC=$(awslocal sns create-topic --name PedidosConcluidos --region us-east-1 | grep TopicArn | cut -d'"' -f4)
echo -e "${GREEN}✅ Tópico SNS criado: $SNS_TOPIC${NC}\n"

# 5. Empacotar Lambdas
echo -e "${YELLOW}5️⃣  Empacotando Lambdas...${NC}"
cd lambdas

# Criar ZIP da Lambda de processar pedido
rm -f processar_pedido.zip
zip -r processar_pedido.zip processar_pedido.py utils/
echo -e "${GREEN}✅ processar_pedido.zip criado!${NC}"

# Criar ZIP da Lambda de criar pedido
rm -f criar_pedido.zip
zip -r criar_pedido.zip criar_pedido.py
echo -e "${GREEN}✅ criar_pedido.zip criado!${NC}\n"

cd ..

# 6. Criar função Lambda - Criar Pedido
echo -e "${YELLOW}6️⃣  Criando Lambda 'CriarPedido'...${NC}"
awslocal lambda create-function \
  --function-name CriarPedido \
  --runtime python3.10 \
  --role arn:aws:iam::000000000000:role/fake-role \
  --handler criar_pedido.lambda_handler \
  --zip-file fileb://lambdas/criar_pedido.zip \
  --region us-east-1 2>/dev/null

echo -e "${GREEN}✅ Lambda CriarPedido criada!${NC}\n"

# 7. Criar função Lambda - Processar Pedido
echo -e "${YELLOW}7️⃣  Criando Lambda 'ProcessarPedido'...${NC}"
awslocal lambda create-function \
  --function-name ProcessarPedido \
  --runtime python3.10 \
  --role arn:aws:iam::000000000000:role/fake-role \
  --handler processar_pedido.lambda_handler \
  --zip-file fileb://lambdas/processar_pedido.zip \
  --region us-east-1 2>/dev/null

echo -e "${GREEN}✅ Lambda ProcessarPedido criada!${NC}\n"

# 8. Criar API Gateway
echo -e "${YELLOW}8️⃣  Criando API Gateway...${NC}"
API_ID=$(awslocal apigateway create-rest-api \
  --name "API de Pedidos" \
  --region us-east-1 | grep id | head -1 | cut -d'"' -f4)

# Obter ID do recurso raiz
ROOT_ID=$(awslocal apigateway get-resources \
  --rest-api-id $API_ID \
  --region us-east-1 | grep id | head -1 | cut -d'"' -f4)

# Criar recurso /pedidos
PEDIDOS_RESOURCE=$(awslocal apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $ROOT_ID \
  --path-part pedidos \
  --region us-east-1 | grep id | cut -d'"' -f4)

# Criar método POST
awslocal apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $PEDIDOS_RESOURCE \
  --http-method POST \
  --authorization-type NONE \
  --region us-east-1 2>/dev/null

# Integrar com Lambda
awslocal apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $PEDIDOS_RESOURCE \
  --http-method POST \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:000000000000:function:CriarPedido/invocations \
  --region us-east-1 2>/dev/null

echo -e "${GREEN}✅ API Gateway criada!${NC}\n"

echo -e "${GREEN}✨ Setup completo! Todos os recursos foram criados.${NC}\n"
echo -e "${YELLOW}Próximos passos:${NC}"
echo "1. Testar API: curl -X POST http://localhost:4566/pedidos -H 'Content-Type: application/json' -d '{\"cliente\":\"João\",\"itens\":[\"Pizza\",\"Refri\"],\"mesa\":5}'"
echo "2. Verificar PDFs no S3: awslocal s3 ls s3://comprovantes"
echo "3. Verificar mensagens SNS: awslocal sns list-subscriptions"