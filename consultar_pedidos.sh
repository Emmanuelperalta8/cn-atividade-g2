#!/bin/bash

# 📊 Script para Consultar Pedidos - Sistema de Restaurante
# Uso: ./consultar_pedidos.sh [filtro_status] [detalhado]

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

FILTRO="${1:-TODOS}"
DETALHADO="${2:-0}"

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  📊 CONSULTA DE PEDIDOS${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

python3 << PYTHON_EOF
import json
import boto3

dynamodb = boto3.resource('dynamodb', endpoint_url='http://localhost:4566', region_name='us-east-1')
s3 = boto3.client('s3', endpoint_url='http://localhost:4566', region_name='us-east-1')

try:
    table = dynamodb.Table('Pedidos')
    response = table.scan()
    pedidos = response['Items']

    if not pedidos:
        print("❌ Nenhum pedido encontrado\n")
        exit(0)

    filtro = "$FILTRO"
    if filtro != "TODOS":
        pedidos = [p for p in pedidos if p.get('status') == filtro]

    if not pedidos:
        print(f"❌ Nenhum pedido com status: {filtro}\n")
        exit(0)

    print(f"✅ Total de pedidos: {len(pedidos)}\n")

    try:
        s3_response = s3.list_objects_v2(Bucket='comprovantes')
        pdfs = [obj['Key'] for obj in s3_response.get('Contents', [])]
    except Exception:
        pdfs = []

    pedidos_ordenados = sorted(
        pedidos,
        key=lambda x: x.get('data_criacao', ''),
        reverse=True
    )

    for i, pedido in enumerate(pedidos_ordenados, 1):
        pedido_id = pedido.get('id', 'SEM_ID')
        status = pedido.get('status', 'N/A')
        cliente = pedido.get('cliente', 'N/A')
        mesa = pedido.get('mesa', 'N/A')
        itens = pedido.get('itens', [])

        status_emoji = "🆕" if status == 'RECEBIDO' else "✅"
        pdf_emoji = "📄" if f"{pedido_id}.pdf" in pdfs else "⏳"

        print(f"{i}. {status_emoji} {cliente} {pdf_emoji}")
        print(f"   ID: {pedido_id}")
        print(f"   Mesa: {mesa}")
        print(f"   Status: {status}")
        print(f"   Itens: {', '.join(itens)}")

        if "$DETALHADO" == "1":
            print(f"   Data: {pedido.get('data_criacao', 'N/A')}")
            if f"{pedido_id}.pdf" in pdfs:
                print(f"   ✅ Comprovante disponível em S3")

        print()

except Exception as e:
    print(f"❌ Erro: {e}\n")
    exit(1)
PYTHON_EOF

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo "📈 Estatísticas:"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"

python3 << STATS_EOF
import boto3

try:
    dynamodb = boto3.resource('dynamodb', endpoint_url='http://localhost:4566', region_name='us-east-1')
    s3 = boto3.client('s3', endpoint_url='http://localhost:4566', region_name='us-east-1')

    table = dynamodb.Table('Pedidos')
    response = table.scan()
    pedidos = response['Items']

    total = len(pedidos)
    recebidos = sum(1 for p in pedidos if p.get('status') == 'RECEBIDO')
    processados = sum(1 for p in pedidos if p.get('status') == 'PROCESSADO')

    s3_response = s3.list_objects_v2(Bucket='comprovantes')
    total_pdfs = len(s3_response.get('Contents', []))

    print(f"  📦 Total de Pedidos: {total}")
    print(f"  🆕 Recebidos: {recebidos}")
    print(f"  ✅ Processados: {processados}")
    print(f"  📄 PDFs Gerados: {total_pdfs}")

    if total > 0:
        taxa = (processados / total * 100)
        print(f"  📊 Taxa de Processamento: {taxa:.1f}%")

except Exception as e:
    print(f"  ❌ Erro ao obter estatísticas: {e}")
STATS_EOF

echo ""