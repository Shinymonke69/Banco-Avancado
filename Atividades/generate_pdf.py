import os
import re
from reportlab.lib.pagesizes import letter
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Preformatted, HRFlowable

def markdown_to_pdf(input_md_path, output_pdf_path):
    with open(input_md_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    doc = SimpleDocTemplate(
        output_pdf_path,
        pagesize=letter,
        leftMargin=40,
        rightMargin=40,
        topMargin=40,
        bottomMargin=40
    )

    styles = getSampleStyleSheet()

    # Cores personalizadas
    c_primary = colors.HexColor('#1E3A8A')    # Azul marinho
    c_secondary = colors.HexColor('#0D9488')  # Verde petróleo
    c_dark = colors.HexColor('#1F2937')       # Texto padrão
    c_code_bg = colors.HexColor('#F8FAFC')    # Fundo código
    c_border = colors.HexColor('#E2E8F0')

    title_style = ParagraphStyle(
        'DocTitle',
        parent=styles['Heading1'],
        fontSize=18,
        leading=22,
        textColor=c_primary,
        spaceAfter=6,
        fontName='Helvetica-Bold'
    )

    h1_style = ParagraphStyle(
        'SectionH1',
        parent=styles['Heading2'],
        fontSize=13,
        leading=16,
        textColor=c_primary,
        spaceBefore=14,
        spaceAfter=6,
        fontName='Helvetica-Bold'
    )

    h2_style = ParagraphStyle(
        'SectionH2',
        parent=styles['Heading3'],
        fontSize=11,
        leading=14,
        textColor=c_secondary,
        spaceBefore=10,
        spaceAfter=4,
        fontName='Helvetica-Bold'
    )

    h3_style = ParagraphStyle(
        'SectionH3',
        parent=styles['Normal'],
        fontSize=10,
        leading=13,
        textColor=colors.HexColor('#374151'),
        spaceBefore=6,
        spaceAfter=2,
        fontName='Helvetica-Bold'
    )

    body_style = ParagraphStyle(
        'DocBody',
        parent=styles['Normal'],
        fontSize=9,
        leading=13,
        textColor=c_dark,
        spaceAfter=4,
        fontName='Helvetica'
    )

    bullet_style = ParagraphStyle(
        'DocBullet',
        parent=body_style,
        leftIndent=14,
        spaceAfter=2
    )

    subbullet_style = ParagraphStyle(
        'DocSubBullet',
        parent=body_style,
        leftIndent=26,
        spaceAfter=2
    )

    code_style = ParagraphStyle(
        'CodeStyle',
        fontName='Courier',
        fontSize=7.0,
        leading=9.0,
        textColor=colors.HexColor('#0F172A'),
        backColor=c_code_bg,
        spaceAfter=0,
        leftIndent=6
    )

    story = []
    in_code_block = False
    code_block_lines = []

    for line in lines:
        raw_line = line.rstrip('\r\n')
        stripped = raw_line.strip()

        # Blocos de código
        if stripped.startswith('```'):
            if in_code_block:
                in_code_block = False
                # Dividir blocos de código grandes em pedaços de no máximo 35 linhas para permitir quebra de página
                chunk_size = 35
                for i in range(0, len(code_block_lines), chunk_size):
                    chunk = code_block_lines[i:i + chunk_size]
                    p_code = Preformatted('\n'.join(chunk), code_style)
                    story.append(p_code)
                    if i + chunk_size < len(code_block_lines):
                        story.append(Spacer(1, 2))
                story.append(Spacer(1, 4))
                code_block_lines = []
            else:
                in_code_block = True
                code_block_lines = []
            continue

        if in_code_block:
            code_block_lines.append(raw_line)
            continue

        if not stripped:
            story.append(Spacer(1, 3))
            continue

        if stripped == '---':
            story.append(HRFlowable(width="100%", thickness=0.8, color=c_border, spaceBefore=4, spaceAfter=4))
            continue

        # Formatação básica de negrito e inline code
        formatted = stripped
        formatted = formatted.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
        formatted = re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', formatted)
        formatted = re.sub(r'`(.+?)`', r'<font face="Courier" color="#9D174D"><b>\1</b></font>', formatted)

        if stripped.startswith('# '):
            story.append(Paragraph(formatted[2:], title_style))
        elif stripped.startswith('## '):
            story.append(Paragraph(formatted[3:], h1_style))
        elif stripped.startswith('### '):
            story.append(Paragraph(formatted[4:], h2_style))
        elif stripped.startswith('#### '):
            story.append(Paragraph(formatted[5:], h3_style))
        elif raw_line.startswith('  * ') or raw_line.startswith('    * ') or raw_line.startswith('    - '):
            story.append(Paragraph(f"&bull; {formatted.lstrip('* -')}", subbullet_style))
        elif stripped.startswith('* ') or stripped.startswith('- '):
            story.append(Paragraph(f"&bull; {formatted.lstrip('* -')}", bullet_style))
        elif re.match(r'^\d+\.\s', stripped):
            num_match = re.match(r'^(\d+\.)\s*(.*)', formatted)
            if num_match:
                story.append(Paragraph(f"<b>{num_match.group(1)}</b> {num_match.group(2)}", bullet_style))
            else:
                story.append(Paragraph(formatted, body_style))
        else:
            story.append(Paragraph(formatted, body_style))

    doc.build(story)
    print(f"Sucesso! PDF gerado em: {output_pdf_path}")

if __name__ == '__main__':
    base_dir = r"C:\Users\gabri\Documents\Banco Avancado\bd-avancado\Atividades"
    
    # 1. Gerar PDF da Etapa 02
    md_file_02 = os.path.join(base_dir, "DOCUMENTO_ENTREGA_TICKETCORE_02.md")
    pdf_file_02 = os.path.join(base_dir, "DOCUMENTO_ENTREGA_TICKETCORE_02.pdf")
    markdown_to_pdf(md_file_02, pdf_file_02)

    # 2. Gerar PDF da Etapa 01
    md_file_01 = os.path.join(base_dir, "DOCUMENTO_ENTREGA_TICKETCORE_01.md")
    pdf_file_01 = os.path.join(base_dir, "DOCUMENTO_ENTREGA_TICKETCORE_01.pdf")
    markdown_to_pdf(md_file_01, pdf_file_01)
