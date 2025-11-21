# 🍽️ Sistema de Processamento de Pedidos - Restaurante

Um sistema serverless completo para processamento de pedidos de restaurante usando AWS Services e LocalStack para desenvolvimento local.

## 📋 Visão Geral

Este projeto implementa uma arquitetura de microserviços para gerenciar pedidos em um restaurante, utilizando:
- **AWS Lambda** para processamento serverless
- **DynamoDB** para armazenamento de dados
- **S3** para armazenamento de comprovantes em PDF
- **SQS** para fila de processamento
- **SNS** para notificações
- **API Gateway** para exposição de endpoints REST
- **LocalStack** para desenvolvimento local

## 🏗️ Arquitetura

Cliente (API) ↓ API Gateway ↓ Lambda (CriarPedido) ↓ DynamoDB (Armazenar) + SQS (Fila) ↓ Lambda (ProcessarPedido) ↓ S3 (Salvar PDF) + SNS (Notificar)

Code

## 📦 Estrutura do Projeto


cn-atividade-g2/ ├── lambdas/ │ ├── criar_pedido.py # Lambda para criar pedidos │ ├── processar_pedido.py # Lambda para processar pedidos │ ├── utils/ │ │ ├── gerar_pdf.py # Função para gerar PDFs │ │ └── init.py │ ├── criar_pedido.zip # ZIP da Lambda CriarPedido │ └── processar_pedido.zip # ZIP da Lambda ProcessarPedido ├── docker-compose.yml # Configuração do LocalStack ├── setup_localstack.sh # Script de setup ├── test_pedidos.py # Testes automatizados ├── processar_manual.py # Script de processamento manual ├── requirements.txt # Dependências Python ├── .gitignore # Git ignore └── README.md # Este arquivo

## 🚀 Início Rápido

### Pré-requisitos
- Docker e Docker Compose
- Python 3.10+
- pip (gerenciador de pacotes Python)

### 1. Clonar o Repositório
```bash
git clone https://github.com/Emmanuelperalta8/cn-atividade-g2.git
cd cn-atividade-g2
2. Criar Ambiente Virtual
bash
python3 -m venv venv
source venv/bin/activate  # Linux/Mac
# ou
venv\Scripts\activate  # Windows
3. Instalar Dependências
bash
pip install -r requirements.txt
4. Iniciar LocalStack
bash
docker-compose up -d
5. Setup do Sistema
bash
./setup_localstack.sh
6. Processar Pedidos
Em um terminal separado:

bash
python3 processar_manual.py
📝 Uso
Criar um Pedido
bash
python3 << 'EOF'
import json
import boto3

lambda_client = boto3.client('lambda', endpoint_url='http://localhost:4566', region_name='us-east-1')

response = lambda_client.invoke(
    FunctionName='CriarPedido',
    InvocationType='RequestResponse',
    Payload=json.dumps({
        'body': json.dumps({
            'cliente': 'João Silva',
            'itens': ['Pizza Margherita', 'Refrigerante'],
            'mesa': 5
        })
    })
)

result = json.loads(response['Payload'].read())
print(result)
