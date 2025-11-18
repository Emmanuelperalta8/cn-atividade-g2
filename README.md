# 🍽️ Restaurante Serverless — Atividade G2

Este projeto simula um sistema de pedidos para um restaurante utilizando arquitetura serverless com AWS Lambda, DynamoDB, SQS, S3 e SNS — tudo rodando localmente via [LocalStack](https://docs.localstack.cloud/).

---

## 📦 Tecnologias e dependências

### Linguagem
- Python 3.10+

### Dependências Python

Instale com:

```bash
pip install boto3 weasyprint

Instale via terminal:

bash
sudo apt update
sudo apt install zip curl

1. Subir o LocalStack
Se estiver usando Docker:

bash
docker run --rm -it -p 4566:4566 -p 4571:4571 localstack/localstack

2. Criar recursos simulados
bash
awslocal dynamodb create-table \
  --table-name Pedidos \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5

awslocal sqs create-queue --queue-name pedidos
awslocal s3 mb s3://comprovantes
awslocal sns create-topic --name PedidosConcluidos


3. Empacotar e criar a função Lambda
bash
cd lambdas
zip -r processar_pedido.zip processar_pedido.py utils/

awslocal lambda create-function \
  --function-name ProcessarPedido \
  --runtime python3.10 \
  --handler processar_pedido.lambda_handler \
  --zip-file fileb://processar_pedido.zip \
  --role arn:aws:iam::000000000000:role/fake-role


4. Simular evento de pedido
Crie o evento:

bash
echo '{"Records":[{"body":"{\"id\":\"12345\"}"}]}' > evento.json
Invocar a função:

bash
awslocal lambda invoke \
  --function-name ProcessarPedido \
  --payload file://evento.json \
  --cli-binary-format raw-in-base64-out \
  resposta.json
5. Verificar PDF gerado
bash
awslocal s3 ls s3://comprovantes
awslocal s3 cp s3://comprovantes/12345.pdf ./comprovante.pdf


📁 Estrutura do projeto
Código
restaurante-serverless/
├── lambdas/
│   ├── processar_pedido.py
│   ├── criar_pedido.py
│   ├── utils/
│   │   └── gerar_pdf.py
├── evento.json
├── resposta.json
├── README.md



