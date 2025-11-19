from datetime import datetime
import json

def gerar_comprovante_pdf(dados_pedido):
    """
    Gera um comprovante em PDF usando FPDF (mais leve que weasyprint)
    
    Args:
        dados_pedido: dict com id, cliente, itens, mesa, status
    
    Returns:
        bytes: conteúdo do PDF
    """
    
    try:
        from fpdf import FPDF
        
        # Criar PDF
        pdf = FPDF()
        pdf.add_page()
        pdf.set_font("Arial", "B", 16)
        pdf.cell(0, 10, "COMPROVANTE DE PEDIDO", ln=True, align="C")
        pdf.ln(10)
        
        # Dados do pedido
        pdf.set_font("Arial", "", 12)
        pdf.cell(0, 8, f"ID: {dados_pedido.get('id', 'N/A')}", ln=True)
        pdf.cell(0, 8, f"Cliente: {dados_pedido.get('cliente', 'N/A')}", ln=True)
        pdf.cell(0, 8, f"Mesa: {dados_pedido.get('mesa', 'N/A')}", ln=True)
        pdf.cell(0, 8, f"Status: {dados_pedido.get('status', 'N/A').upper()}", ln=True)
        pdf.cell(0, 8, f"Data/Hora: {datetime.now().strftime('%d/%m/%Y %H:%M:%S')}", ln=True)
        
        # Itens
        pdf.ln(5)
        pdf.set_font("Arial", "B", 12)
        pdf.cell(0, 8, "Itens do Pedido:", ln=True)
        pdf.set_font("Arial", "", 11)
        
        itens = dados_pedido.get('itens', [])
        if isinstance(itens, str):
            try:
                itens = json.loads(itens)
            except:
                itens = [itens]
        
        if isinstance(itens, list):
            for item in itens:
                pdf.cell(0, 7, f"  - {item}", ln=True)
        else:
            pdf.cell(0, 7, f"  - {itens}", ln=True)
        
        # Rodapé
        pdf.ln(10)
        pdf.set_font("Arial", "I", 10)
        pdf.cell(0, 8, "Obrigado pela preferencia!", ln=True, align="C")
        pdf.cell(0, 8, f"Gerado em {datetime.now().strftime('%d/%m/%Y às %H:%M:%S')}", ln=True, align="C")
        
        # Retornar como bytes
        pdf_bytes = pdf.output()
        return pdf_bytes
    
    except Exception as e:
        print(f"Erro ao gerar PDF: {str(e)}")
        raise