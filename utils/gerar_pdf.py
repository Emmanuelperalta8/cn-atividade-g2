from jinja2 import Environment, FileSystemLoader
from weasyprint import HTML
import io

def gerar_comprovante_pdf(dados):
    env = Environment(loader=FileSystemLoader('templates'))
    template = env.get_template('comprovante_template.html')
    html_content = template.render(dados)

    pdf_io = io.BytesIO()
    HTML(string=html_content).write_pdf(pdf_io)
    return pdf_io.getvalue()
