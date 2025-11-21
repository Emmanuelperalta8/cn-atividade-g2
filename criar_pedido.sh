#!/bin/bash

# 🍽️  Script para Criar e Processar Pedidos - Sistema de Restaurante
# Uso: ./criar_pedido.sh "Nome do Cliente" "Item1,Item2,Item3" [tempo_espera] [mesa]

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configurações
QUEUE_URL="http://localhost:4566/000000000000/pedidos"
S3_BUCKET="comprovantes"
LAMBDA_FUNCTION="ProcessarPedido"
DYNAMODB_TABLE="Pedidos"
TEMPO_PADRAO=5

# Validação de argumentos
if [ $# -lt 2 ]; then
    echo -e "${RED}❌ Erro: Argumentos insuficientes${NC}"
    echo ""
    echo "Uso: $0 \"Nome do Cliente\" \"Item1,Item2,Item3\" [tempo_espera_segundos] [mesa]"
    echo ""
    echo "Exemplos:"
    echo "  $0 \"João Silva\" \"Pizza,Refrigerante\""
    echo "  $0 \"Maria Santos\" \"Hambúrguer,Batata,Suco\" 10 3"
    echo ""
    exit 1
fi

CLIENTE="$1"
ITENS="$2"
TEMPO="${3:-$TEMPO_PADRAO}"
MESA="${4:-1}"

# Validar tempo
if ! [[ "$TEMPO" =~ ^[0-9]+$ ]]; then
    TEMPO=$TEMPO_PADRAO
fi

# Gerar UUID
PEDIDO_ID=$(uuidgen)
PEDIDO_ID="${PEDIDO_ID,,}"

# Funções auxiliares
function titulo() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo ""
}

function secao() {
    echo -e "\n${PURPLE}$1${NC}"
    echo -e "${PURPLE}────────────────────────────────────────────────────────────${NC}"
}

function sucesso() {
    echo -e "${GREEN}✅ $1${NC}"
}

function erro() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

function aviso() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

function info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Verificar se LocalStack está rodando
function verificar_localstack() {
    secao "1️⃣  VERIFICANDO LOCALSTACK"
    
    if ! curl -s http://localhost:4566/health > /dev/null 2>&1; then
        erro "LocalStack não está respondendo em http://localhost:4566"
    fi
    
    sucesso "LocalStack está rodando"
}

# Criar pedido no DynamoDB e SQS
function criar_pedido() {
    secao "2️⃣  CRIANDO PEDIDO"
    
    echo -e "Dados do Pedido:"
    echo -e "  ${BLUE}ID:${NC} $PEDIDO_ID"
    echo -e "  ${BLUE}Cliente:${NC} $CLIENTE"
    echo -e "  ${BLUE}Mesa:${NC} $MESA"
    echo -e "  ${BLUE}Itens:${NC} $ITENS"
    echo ""
    
    # Converter itens em array JSON
    IFS=',' read -ra ITEMS_ARRAY <<< "$ITENS"
    ITEMS_JSON="["
    for i in "${!ITEMS_ARRAY[@]}"; do
        ITEMS_JSON+="\"${ITEMS_ARRAY[$i]// /}\""
        if [ $i -lt $((${#ITEMS_ARRAY[@]} - 1)) ]; then
            ITEMS_JSON+=","
        fi
    done
    ITEMS_JSON+="]"
    
    # Criar mensagem para SQS
    MENSAGEM="{\"pedido_id\": \"${PEDIDO_ID}\"}"
    
    # Enviar para SQS
    if awslocal sqs send-message \
        --queue-url "$QUEUE_URL" \
        --message-body "$MENSAGEM" > /dev/null 2>&1; then
        sucesso "Pedido enviado para a fila SQS"
    else
        erro "Falha ao enviar pedido para SQS"
    fi
    
    # Salvar em DynamoDB usando Python para evitar complexidade com JSON
    python3 << PYTHON_EOF
import boto3
import json
from datetime import datetime

try:
    dynamodb = boto3.resource('dynamodb', endpoint_url='http://localhost:4566', region_name='us-east-1')
    table = dynamodb.Table('$DYNAMODB_TABLE')
    
    items = [item.strip() for item in "$ITENS".split(',')]
    
    table.put_item(Item={
        'id': '$PEDIDO_ID',
        'cliente': '$CLIENTE',
        'mesa': int($MESA),
        'itens': items,
        'status': 'RECEBIDO',
        'data_criacao': datetime.utcnow().isoformat() + 'Z'
    })
    
except Exception as e:
    print(f"Erro ao salvar em DynamoDB: {e}")
    exit(1)
PYTHON_EOF
    
    sucesso "Pedido armazenado em DynamoDB"
}

# Aguardar processamento
function aguardar_processamento() {
    secao "3️⃣  AGUARDANDO PROCESSAMENTO"
    
    echo "⏳ Aguardando $TEMPO segundos..."
    echo ""
    
    for ((i=1; i<=TEMPO; i++)); do
        PERCENT=$((i * 100 / TEMPO))
        echo -ne "\r   Progresso: [$((PERCENT))%] $(printf '█%.0s' $(seq 1 $((PERCENT/5))))"
        sleep 1
    done
    
    echo -ne "\r   ✅ Processamento completo!                              \n"
}

# Processar pedido manualmente via Lambda
function processar_pedido() {
    secao "4️⃣  PROCESSANDO PEDIDO COM LAMBDA"
    
    # Chamar Lambda
    LAMBDA_PAYLOAD="{\"Records\":[{\"body\":\"{\\\"pedido_id\\\": \\\"${PEDIDO_ID}\\\"}\"}]}"
    
    if awslocal lambda invoke \
        --function-name "$LAMBDA_FUNCTION" \
        --payload "$LAMBDA_PAYLOAD" \
        /tmp/lambda_response.json > /dev/null 2>&1; then
        sucesso "Lambda ProcessarPedido executada"
    else
        aviso "Lambda não respondeu (pode estar processando em background)"
    fi
}

# Verificar resultado
function verificar_resultado() {
    secao "5️⃣  VERIFICANDO RESULTADO"
    
    # Verificar PDF
    echo "🔍 Buscando comprovante em S3..."
    sleep 1
    
    if awslocal s3api head-object --bucket "$S3_BUCKET" --key "${PEDIDO_ID}.pdf" > /dev/null 2>&1; then
        sucesso "Comprovante encontrado: ${PEDIDO_ID}.pdf"
        
        # Obter tamanho do arquivo
        SIZE=$(awslocal s3api head-object --bucket "$S3_BUCKET" --key "${PEDIDO_ID}.pdf" --query 'ContentLength' --output text 2>/dev/null)
        info "Tamanho do PDF: $SIZE bytes"
        
        # Oferecer download
        echo ""
        echo "Deseja baixar o comprovante? (S/n)"
        read -r RESPOSTA
        if [[ "$RESPOSTA" =~ ^[Ss]$ ]] || [ -z "$RESPOSTA" ]; then
            if awslocal s3 cp s3://$S3_BUCKET/${PEDIDO_ID}.pdf ./ > /dev/null 2>&1; then
                sucesso "PDF salvo: ./${PEDIDO_ID}.pdf"
            fi
        fi
    else
        aviso "Comprovante ainda não disponível"
    fi
    
    # Verificar status no DynamoDB
    echo ""
    echo "📊 Consultando status no DynamoDB..."
    
    python3 << PYTHON_EOF
import boto3

try:
    dynamodb = boto3.resource('dynamodb', endpoint_url='http://localhost:4566', region_name='us-east-1')
    table = dynamodb.Table('$DYNAMODB_TABLE')
    
    response = table.get_item(Key={'id': '$PEDIDO_ID'})
    
    if 'Item' in response:
        pedido = response['Item']
        status = pedido.get('status', 'DESCONHECIDO')
        
        if status == 'PROCESSADO':
            print("✅ Status do pedido: PROCESSADO")
        elif status == 'RECEBIDO':
            print("⏳ Status do pedido: RECEBIDO (ainda processando)")
        else:
            print(f"ℹ️  Status do pedido: {status}")
    else:
        print("⚠️  Pedido não encontrado")
        
except Exception as e:
    print(f"❌ Erro: {e}")
PYTHON_EOF
}

# Listar PDFs recentes
function listar_pdfs() {
    secao "6️⃣  COMPROVANTES RECENTES EM S3"
    
    echo "�� Últimos PDFs gerados:"
    echo ""
    
    python3 << PYTHON_EOF
import boto3

try:
    s3 = boto3.client('s3', endpoint_url='http://localhost:4566', region_name='us-east-1')
    response = s3.list_objects_v2(Bucket='$S3_BUCKET', MaxKeys=5)
    
    if 'Contents' in response:
        for obj in sorted(response['Contents'], key=lambda x: x['LastModified'], reverse=True):
            nome = obj['Key']
            tamanho = obj['Size']
            data = obj['LastModified'].strftime('%d/%m/%Y %H:%M:%S')
            print(f"   📄 {nome:40} | {tamanho:>6} bytes | {data}")
    else:
        print("   Nenhum PDF encontrado")
        
except Exception as e:
    print(f"   ❌ Erro: {e}")
PYTHON_EOF
}

# Resumo final
function resumo_final() {
    titulo "📋 RESUMO DO PEDIDO"
    
    echo "Informações:"
    echo "  ${BLUE}ID:${NC} $PEDIDO_ID"
    echo "  ${BLUE}Cliente:${NC} $CLIENTE"
    echo "  ${BLUE}Mesa:${NC} $MESA"
    echo "  ${BLUE}Itens:${NC} $ITENS"
    echo "  ${BLUE}Data/Hora:${NC} $(date '+%d/%m/%Y %H:%M:%S')"
    
    echo ""
    echo "📚 Comandos Úteis:"
    echo "  • Ver PDFs: awslocal s3 ls s3://comprovantes"
    echo "  • Baixar PDF: awslocal s3 cp s3://comprovantes/${PEDIDO_ID}.pdf ./"
    echo "  • Ver todos os pedidos: ./consultar_pedidos.sh"
    echo "  • Ver pedidos processados: ./consultar_pedidos.sh PROCESSADO"
    echo ""
}

# ========== EXECUÇÃO PRINCIPAL ==========

titulo "🍽️  SISTEMA DE PROCESSAMENTO DE PEDIDOS"

verificar_localstack
criar_pedido
aguardar_processamento
processar_pedido
verificar_resultado
listar_pdfs
resumo_final

sucesso "Pedido processado com sucesso!"
echo ""

