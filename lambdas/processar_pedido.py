import os
import json
from datetime import datetime

import boto3
from botocore.exceptions import ClientError

# --- ReportLab Imports para Geração de PDF ---
from reportlab.lib.pagesizes import letter
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.lib.colors import black
# ---------------------------------------------

# Configuração do LocalStack
LOCALSTACK_ENDPOINT = os.environ.get('LOCALSTACK_ENDPOINT') or 'http://localhost:4566'
REGION_NAME = 'us-east-1'
DYNAMODB_TABLE_NAME = 'Pedidos'
S3_BUCKET_NAME = 'comprovantes'


# --- INICIALIZAÇÃO GLOBAL DE ESTILOS (CORREÇÃO DE KEYERROR) ---
# Os estilos devem ser definidos uma única vez.
STYLES = getSampleStyleSheet()

# Estilos customizados
# Adicionamos a verificação para evitar o KeyError, caso o estilo já exista
if 'TitleCustom' not in STYLES:
    STYLES.add(ParagraphStyle(name='TitleCustom', parent=STYLES['h1'], alignment=1, spaceAfter=20))
if 'Heading2Custom' not in STYLES:
    STYLES.add(ParagraphStyle(name='Heading2Custom', parent=STYLES['h2'], spaceAfter=10))
if 'ItemCustom' not in STYLES:
    STYLES.add(ParagraphStyle(name='ItemCustom', parent=STYLES['Normal'], leftIndent=20))


# Inicialização dos clientes AWS
def get_aws_client(service_name):
    return boto3.client(
        service_name,
        endpoint_url=LOCALSTACK_ENDPOINT,
        region_name=REGION_NAME
    )

def get_dynamodb_resource():
    return boto3.resource(
        'dynamodb',
        endpoint_url=LOCALSTACK_ENDPOINT,
        region_name=REGION_NAME
    )

# --- Funções Auxiliares ---

def buscar_pedido_dynamodb(pedido_id):
    """ Busca o item completo do DynamoDB usando o pedido_id. """
    dynamodb = get_dynamodb_resource()
    table = dynamodb.Table(DYNAMODB_TABLE_NAME)
    try:
        response = table.get_item(Key={'id': pedido_id})
        return response.get('Item')
    except ClientError as e:
        print(f"Erro ao buscar pedido {pedido_id} no DynamoDB: {e}")
        return None

# --- Funções de Negócio ---

def gerar_comprovante_pdf(pedido, nome_arquivo_pdf):
    """
    Gera um comprovante de pedido em PDF.
    """
    doc = SimpleDocTemplate(nome_arquivo_pdf, pagesize=letter)
    story = []

    # Título (Usando o estilo inicializado globalmente)
    story.append(Paragraph("<b>COMPROVANTE DO PEDIDO</b>", STYLES['TitleCustom']))

    # Detalhes Principais
    story.append(Paragraph(f"<b>ID do Pedido:</b> {pedido['id']}", STYLES['Normal']))
    story.append(Paragraph(f"<b>Cliente:</b> {pedido.get('cliente', 'Não informado')}", STYLES['Normal']))
    story.append(Paragraph(f"<b>Mesa:</b> {pedido.get('mesa', 'N/A')}", STYLES['Normal']))
    story.append(Paragraph(f"<b>Status:</b> <font color='green'>CONCLUÍDO</font>", STYLES['Normal']))
    story.append(Spacer(1, 0.3 * inch))

    # Itens do Pedido
    story.append(Paragraph("<b>--- ITENS DO PEDIDO ---</b>", STYLES['Heading2Custom']))
    
    total_itens = 0
    itens = pedido.get('itens', [])
    if isinstance(itens, list):
        for item in itens:
            story.append(Paragraph(f"* {item}", STYLES['ItemCustom']))
            total_itens += 1
    else:
         print(f"Aviso: O campo 'itens' do pedido {pedido['id']} não é uma lista.")
         
    story.append(Spacer(1, 0.1 * inch))

    # Estatísticas e Rodapé
    story.append(Paragraph("<b>--- DETALHES GERAIS ---</b>", STYLES['Heading2Custom']))
    story.append(Paragraph(f"<b>Total de itens:</b> {total_itens}", STYLES['Normal']))
    story.append(Spacer(1, 0.1 * inch))
    
    data_geracao = datetime.now().strftime('%d/%m/%Y %H:%M:%S')
    story.append(Paragraph(f"<b>Gerado em:</b> {data_geracao}", STYLES['Normal']))

    doc.build(story)
    print(f"PDF {nome_arquivo_pdf} gerado com sucesso.")


def processar_pedido(pedido):
    """
    Função principal que orquestra a geração do PDF e atualização do DB.
    """
    dynamodb = get_dynamodb_resource()
    s3 = get_aws_client('s3')
    
    pedido_id = pedido['id']
    print(f"Processando pedido ID: {pedido_id}")
    
    # 1. Geração do Comprovante PDF
    pdf_filename = f"{pedido_id}.pdf"
    temp_filepath = f'/tmp/{pdf_filename}' 
    gerar_comprovante_pdf(pedido, temp_filepath)

    try:
        # 2. Upload do PDF para o S3
        s3.upload_file(
            temp_filepath,
            S3_BUCKET_NAME,
            pdf_filename
        )
        print(f"PDF salvo em s3://{S3_BUCKET_NAME}/{pdf_filename}")

        # 3. Atualização do Status no DynamoDB
        table = dynamodb.Table(DYNAMODB_TABLE_NAME)
        table.update_item(
            Key={'id': pedido_id},
            UpdateExpression="SET #status = :val",
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={':val': 'CONCLUÍDO'}
        )
        print(f"Status do pedido {pedido_id} atualizado para CONCLUÍDO")

    except ClientError as e:
        print(f"Erro ao processar pedido {pedido_id}: {e}")
        # Em produção, você logaria e relançaria. Aqui estamos relançando no handler.
        raise e

    finally:
        # Limpa o arquivo temporário
        if os.path.exists(temp_filepath):
            os.remove(temp_filepath)
            print(f"Arquivo temporário {temp_filepath} removido.")


# --- Lambda Handler (Versão Corrigida) ---

def lambda_handler(event, context):
    """
    Função principal acionada pelo SQS.
    """
    print(f"Recebidos {len(event['Records'])} registros SQS.")
    
    for record in event['Records']:
        pedido_id = None 
        try:
            # 1. Extrai APENAS o ID do Pedido da mensagem SQS
            message_body = json.loads(record['body'])
            pedido_id = message_body.get('pedido_id') 
            
            if not pedido_id:
                print(f"Mensagem SQS inválida: 'pedido_id' não encontrado.")
                continue

            # 2. BUSCA O PEDIDO COMPLETO NO DYNAMODB
            pedido_data = buscar_pedido_dynamodb(pedido_id)

            if not pedido_data:
                print(f"Pedido {pedido_id} não encontrado no DynamoDB. Pulando.")
                continue

            # 3. Processa o pedido completo
            # SE houver sucesso no processar_pedido, a Lambda retorna 200 e o SQS apaga a mensagem.
            processar_pedido(pedido_data)

        except json.JSONDecodeError:
            print(f"Erro ao decodificar JSON da mensagem: {record['body']}")
        except Exception as e:
            # Relança o erro para que o SQS tente novamente.
            print(f"ERRO CRÍTICO no processamento do pedido {pedido_id}: {e}")
            raise e 

    return {
        'statusCode': 200,
        'body': 'Pedidos processados com sucesso.'
    }