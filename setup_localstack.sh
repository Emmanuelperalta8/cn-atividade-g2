#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🚀 Iniciando setup do LocalStack...${NC}\n"

# Aguardar LocalStack iniciar
echo -e "${YELLOW}⏳ Aguardando LocalStack iniciar...${NC}"
sleep 10

# 1. Criar tabela DynamoDB
echo -e "${YELLOW}1️⃣  Criando tabela DynamoDB 'Pedidos'...${NC}"
awslocal dynamodb create-table \
  --table-name Pedidos \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-east-1 2>/dev/null || true

echo -e "${GREEN}✅ Tabela DynamoDB criada (ou já existia)!${NC}\n"

# 2. Criar fila SQS
echo -e "${YELLOW}2️⃣  Criando fila SQS 'pedidos'...${NC}"
QUEUE_URL=$(awslocal sqs create-queue \
  --queue-name pedidos \
  --region us-east-1 \
  --query 'QueueUrl' \
  --output text 2>/dev/null || true)
echo -e "${GREEN}✅ Fila SQS criada! URL: ${QUEUE_URL}${NC}\n"

# 3. Criar bucket S3
echo -e "${YELLOW}3️⃣  Criando bucket S3 'comprovantes'...${NC}"
awslocal s3 mb s3://comprovantes --region us-east-1 2>/dev/null || true
echo -e "${GREEN}✅ Bucket S3 criado (ou já existia)!${NC}\n"

# 4. Criar tópico SNS
echo -e "${YELLOW}4️⃣  Criando tópico SNS 'PedidosConcluidos'...${NC}"
SNS_TOPIC=$(awslocal sns create-topic \
  --name PedidosConcluidos \
  --region us-east-1 \
  --query 'TopicArn' \
  --output text 2>/dev/null || true)
echo -e "${GREEN}✅ Tópico SNS criado! ARN: ${SNS_TOPIC}${NC}\n"

# 5. Empacotar Lambdas
echo -e "${YELLOW}5️⃣  Empacotando Lambdas...${NC}"
cd lambdas || exit 1

rm -f criar_pedido.zip processar_pedido.zip
zip -r criar_pedido.zip criar_pedido.py > /dev/null 2>&1
zip -r processar_pedido.zip processar_pedido.py > /dev/null 2>&1

echo -e "${GREEN}✅ Lambdas empacotadas!${NC}\n"
cd ..

# 6. Criar função Lambda - Criar Pedido
echo -e "${YELLOW}6️⃣  Criando Lambda 'CriarPedido'...${NC}"
awslocal lambda create-function \
  --function-name CriarPedido \
  --runtime python3.10 \
  --role arn:aws:iam::000000000000:role/fake-role \
  --handler criar_pedido.lambda_handler \
  --zip-file fileb://lambdas/criar_pedido.zip \
  --region us-east-1 2>/dev/null || true

echo -e "${GREEN}✅ Lambda CriarPedido criada (ou já existia)!${NC}\n"

# 7. Criar função Lambda - Processar Pedido
echo -e "${YELLOW}7️⃣  Criando Lambda 'ProcessarPedido'...${NC}"
awslocal lambda create-function \
  --function-name ProcessarPedido \
  --runtime python3.10 \
  --role arn:aws:iam::000000000000:role/fake-role \
  --handler processar_pedido.lambda_handler \
  --zip-file fileb://lambdas/processar_pedido.zip \
  --region us-east-1 2>/dev/null || true

echo -e "${GREEN}✅ Lambda ProcessarPedido criada (ou já existia)!${NC}\n"

# 8. Criar API Gateway
echo -e "${YELLOW}8️⃣  Criando API Gateway...${NC}"
API_ID=$(awslocal apigateway create-rest-api \
  --name "API de Pedidos" \
  --region us-east-1 \
  --query 'id' \
  --output text 2>/dev/null || true)

ROOT_ID=$(awslocal apigateway get-resources \
  --rest-api-id "$API_ID" \
  --region us-east-1 \
  --query 'items[0].id' \
  --output text 2>/dev/null)

PEDIDOS_RESOURCE=$(awslocal apigateway create-resource \
  --rest-api-id "$API_ID" \
  --parent-id "$ROOT_ID" \
  --path-part pedidos \
  --region us-east-1 \
  --query 'id' \
  --output text 2>/dev/null)

awslocal apigateway put-method \
  --rest-api-id "$API_ID" \
  --resource-id "$PEDIDOS_RESOURCE" \
  --http-method POST \
  --authorization-type NONE \
  --region us-east-1 2>/dev/null || true

awslocal apigateway put-integration \
  --rest-api-id "$API_ID" \
  --resource-id "$PEDIDOS_RESOURCE" \
  --http-method POST \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:000000000000:function:CriarPedido/invocations \
  --region us-east-1 2>/dev/null || true

echo -e "${GREEN}✅ API Gateway criada! API_ID: ${API_ID}${NC}\n"

# 9. Conectar ProcessarPedido à fila SQS
echo -e "${YELLOW}9️⃣  Conectando Lambda ProcessarPedido à fila SQS...${NC}"
awslocal lambda create-event-source-mapping \
  --event-source-arn arn:aws:sqs:us-east-1:000000000000:pedidos \
  --function-name ProcessarPedido \
  --enabled \
  --batch-size 10 \
  --region us-east-1 2>/dev/null || true

echo -e "${GREEN}✅ Event Source Mapping criado (ou já existia)!${NC}\n"

echo -e "${GREEN}✨ Setup completo! Sistema pronto para uso.${NC}\n"
echo -e "${YELLOW}📝 Dicas de teste:${NC}"
echo "• Criar pedido pelo script: ./criar_pedido_simples.sh \"João\" \"Pizza,Refri\" 5"
echo "• Ver pedidos: ./consultar_pedidos.sh"
echo "• Ver PDFs: awslocal s3 ls s3://comprovantes"