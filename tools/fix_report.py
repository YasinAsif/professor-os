from pathlib import Path
from copy import deepcopy
import re

from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_LINE_SPACING
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_CELL_VERTICAL_ALIGNMENT
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor


SRC = Path(r"C:\Users\Ghazi Imam Computer\Downloads\ProfessorOS_FYP_Report (1).docx")
OUT = Path(r"E:\FYP_YASIN\ProfessorOS_FYP_Report_Formatted.docx")


def set_run_font(run, name="Times New Roman", size=12, bold=None, italic=None, color=None):
    run.font.name = name
    run._element.get_or_add_rPr().get_or_add_rFonts().set(qn("w:ascii"), name)
    run._element.get_or_add_rPr().get_or_add_rFonts().set(qn("w:hAnsi"), name)
    run.font.size = Pt(size)
    if bold is not None:
        run.bold = bold
    if italic is not None:
        run.italic = italic
    if color:
        run.font.color.rgb = RGBColor(*color)


def get_style(styles, name, style_type=1):
    for s in styles:
        if s.name == name:
            return s
    return styles.add_style(name, style_type)


def set_cell_shading(cell, fill):
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = tc_pr.find(qn("w:shd"))
    if shd is None:
        shd = OxmlElement("w:shd")
        tc_pr.append(shd)
    shd.set(qn("w:fill"), fill)


def set_cell_border(cell, **kwargs):
    tc = cell._tc
    tc_pr = tc.get_or_add_tcPr()
    borders = tc_pr.first_child_found_in("w:tcBorders")
    if borders is None:
        borders = OxmlElement("w:tcBorders")
        tc_pr.append(borders)
    for edge in ("top", "left", "bottom", "right", "insideH", "insideV"):
        if edge in kwargs:
            tag = "w:%s" % edge
            element = borders.find(qn(tag))
            if element is None:
                element = OxmlElement(tag)
                borders.append(element)
            for key in ["val", "sz", "space", "color"]:
                if key in kwargs[edge]:
                    element.set(qn("w:%s" % key), str(kwargs[edge][key]))


def set_cell_margins(cell, top=90, start=100, bottom=90, end=100):
    tc = cell._tc
    tc_pr = tc.get_or_add_tcPr()
    tc_mar = tc_pr.first_child_found_in("w:tcMar")
    if tc_mar is None:
        tc_mar = OxmlElement("w:tcMar")
        tc_pr.append(tc_mar)
    for m, v in (("top", top), ("start", start), ("bottom", bottom), ("end", end)):
        node = tc_mar.find(qn("w:%s" % m))
        if node is None:
            node = OxmlElement("w:%s" % m)
            tc_mar.append(node)
        node.set(qn("w:w"), str(v))
        node.set(qn("w:type"), "dxa")


def keep_with_next(p):
    p_pr = p._p.get_or_add_pPr()
    node = p_pr.find(qn("w:keepNext"))
    if node is None:
        p_pr.append(OxmlElement("w:keepNext"))


def page_break_before(p):
    p_pr = p._p.get_or_add_pPr()
    node = p_pr.find(qn("w:pageBreakBefore"))
    if node is None:
        p_pr.append(OxmlElement("w:pageBreakBefore"))


def iter_blocks(parent):
    parent_elm = parent.element.body if hasattr(parent, "element") else parent._tc
    for child in parent_elm.iterchildren():
        if child.tag == qn("w:p"):
            yield ("p", child)
        elif child.tag == qn("w:tbl"):
            yield ("tbl", child)


def insert_paragraph_before_table(table, text, styles, style="Caption"):
    p = OxmlElement("w:p")
    table._tbl.addprevious(p)
    paragraph = table._parent.add_paragraph()
    paragraph._p.getparent().remove(paragraph._p)
    paragraph._p = p
    paragraph._element = p
    paragraph.style = get_style(styles, style)
    paragraph.add_run(text)
    return paragraph


def replace_all_text(doc):
    # Normalize malformed dash/quote characters introduced by source conversion.
    replacements = {
        "—": "-",  # strict removal requested
        "–": "-",
        "‑": "-",
        "�": "-",
        "’": "'",
        "‘": "'",
        "“": '"',
        "”": '"',
    }
    def clean(s):
        for old, new in replacements.items():
            s = s.replace(old, new)
        return s
    for p in doc.paragraphs:
        if p.text:
            for r in p.runs:
                r.text = clean(r.text)
    for table in doc.tables:
        for row in table.rows:
            for cell in row.cells:
                for p in cell.paragraphs:
                    for r in p.runs:
                        r.text = clean(r.text)
    for section in doc.sections:
        for part in (section.header, section.footer):
            for p in part.paragraphs:
                for r in p.runs:
                    r.text = clean(r.text)


def style_document(doc):
    styles = doc.styles
    normal = get_style(styles, "Normal")
    normal.font.name = "Times New Roman"
    normal._element.rPr.rFonts.set(qn("w:ascii"), "Times New Roman")
    normal._element.rPr.rFonts.set(qn("w:hAnsi"), "Times New Roman")
    normal.font.size = Pt(12)
    normal.paragraph_format.space_after = Pt(6)
    normal.paragraph_format.line_spacing = 1.15

    h1 = get_style(styles, "Heading 1")
    h1.font.name = "Times New Roman"
    h1._element.rPr.rFonts.set(qn("w:ascii"), "Times New Roman")
    h1._element.rPr.rFonts.set(qn("w:hAnsi"), "Times New Roman")
    h1.font.size = Pt(16)
    h1.font.bold = True
    h1.font.color.rgb = RGBColor(31, 78, 121)
    h1.paragraph_format.space_before = Pt(18)
    h1.paragraph_format.space_after = Pt(10)
    h1.paragraph_format.keep_with_next = True

    h2 = get_style(styles, "Heading 2")
    h2.font.name = "Times New Roman"
    h2._element.rPr.rFonts.set(qn("w:ascii"), "Times New Roman")
    h2._element.rPr.rFonts.set(qn("w:hAnsi"), "Times New Roman")
    h2.font.size = Pt(13)
    h2.font.bold = True
    h2.font.color.rgb = RGBColor(31, 78, 121)
    h2.paragraph_format.space_before = Pt(12)
    h2.paragraph_format.space_after = Pt(6)
    h2.paragraph_format.keep_with_next = True

    h3 = get_style(styles, "Heading 3")
    h3.font.name = "Times New Roman"
    h3._element.rPr.rFonts.set(qn("w:ascii"), "Times New Roman")
    h3._element.rPr.rFonts.set(qn("w:hAnsi"), "Times New Roman")
    h3.font.size = Pt(12)
    h3.font.bold = True
    h3.font.color.rgb = RGBColor(55, 55, 55)
    h3.paragraph_format.space_before = Pt(8)
    h3.paragraph_format.space_after = Pt(4)
    h3.paragraph_format.keep_with_next = True

    cap = get_style(styles, "Caption")
    cap.font.name = "Times New Roman"
    cap._element.rPr.rFonts.set(qn("w:ascii"), "Times New Roman")
    cap._element.rPr.rFonts.set(qn("w:hAnsi"), "Times New Roman")
    cap.font.size = Pt(10.5)
    cap.font.italic = True
    cap.font.color.rgb = RGBColor(70, 70, 70)
    cap.paragraph_format.space_before = Pt(4)
    cap.paragraph_format.space_after = Pt(8)
    cap.paragraph_format.keep_with_next = True

    for p in doc.paragraphs:
        p.paragraph_format.widow_control = True
        if p.style and p.style.name in ("Heading 1", "Heading 2", "Heading 3"):
            keep_with_next(p)
        elif p.style and p.style.name == "Normal":
            p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    for s in doc.sections:
        s.top_margin = Inches(1)
        s.bottom_margin = Inches(1)
        s.left_margin = Inches(1)
        s.right_margin = Inches(1)


def format_title_pages(doc):
    # Enlarge and complete the title block on the opening pages while preserving source wording.
    title_idxs = [1, 2, 15, 16]
    for i in title_idxs:
        if i >= len(doc.paragraphs):
            continue
        p = doc.paragraphs[i]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p.paragraph_format.space_before = Pt(10 if i in (1, 15) else 4)
        p.paragraph_format.space_after = Pt(8)
        for r in p.runs:
            set_run_font(r, size=22 if i in (1, 15) else 14, bold=(i in (1, 15)), color=(31, 78, 121))
    for i in range(min(24, len(doc.paragraphs))):
        p = doc.paragraphs[i]
        if p.text.strip():
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            if i not in title_idxs:
                p.paragraph_format.space_after = Pt(5)
                for r in p.runs:
                    set_run_font(r, size=12)
    # Make the main title explicitly visible on the first title page.
    if len(doc.paragraphs) > 1:
        p = doc.paragraphs[1]
        p.paragraph_format.space_before = Pt(20)
        p.paragraph_format.space_after = Pt(14)


def format_figures_and_tables(doc):
    # Determine chapter while walking the body, add captions for tables, and normalize figure captions.
    chapter = 0
    context_title = ""
    table_counts = {}
    figure_counts = {}
    body = doc.element.body
    table_by_elm = {t._tbl: t for t in doc.tables}
    for child in list(body.iterchildren()):
        if child.tag == qn("w:p"):
            p = next((x for x in doc.paragraphs if x._p is child), None)
            if not p:
                continue
            txt = " ".join(p.text.split())
            m = re.match(r"CHAPTER\s+(\d+)", txt, re.I)
            if m:
                chapter = int(m.group(1))
                continue
            if p.style and p.style.name in ("Heading 2", "Heading 3"):
                context_title = txt
            if re.match(r"Figure\s+\d+\.\d+", txt, re.I):
                # Existing figure captions: enforce a clean caption style and consistent punctuation.
                p.style = get_style(doc.styles, "Caption")
                p.alignment = WD_ALIGN_PARAGRAPH.CENTER
                for r in p.runs:
                    set_run_font(r, size=10.5, italic=True, color=(70, 70, 70))
                keep_with_next(p)
        elif child.tag == qn("w:tbl") and child in table_by_elm:
            table = table_by_elm[child]
            if chapter == 0:
                chapter = 1
            table_counts[chapter] = table_counts.get(chapter, 0) + 1
            num = f"{chapter}.{table_counts[chapter]}"
            headers = [" ".join(c.text.split()) for c in table.rows[0].cells]
            lead = headers[0] if headers else "Data"
            lead = re.sub(r"[^A-Za-z0-9 /&()]+", "", lead)[:70].strip()
            if lead == "Field" and context_title:
                lead = f"Details for {context_title}"
            elif lead in ("ID", "Requirement", "Constraint ID") and context_title:
                lead = f"{lead} details for {context_title}"
            caption = f"Table {num}: {lead or 'Data table'}"
            cp = insert_paragraph_before_table(table, caption, doc.styles)
            cp.alignment = WD_ALIGN_PARAGRAPH.CENTER
            for r in cp.runs:
                set_run_font(r, size=10.5, italic=True, color=(70, 70, 70))
            # Table polish: repeat header row, shaded header, comfortable padding, fixed table width.
            table.alignment = WD_TABLE_ALIGNMENT.CENTER
            table.autofit = True
            for ri, row in enumerate(table.rows):
                tr_pr = row._tr.get_or_add_trPr()
                if ri == 0:
                    repeat = OxmlElement("w:tblHeader")
                    repeat.set(qn("w:val"), "true")
                    tr_pr.append(repeat)
                for cell in row.cells:
                    cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
                    set_cell_margins(cell)
                    set_cell_border(cell, top={"val":"single","sz":"4","color":"B7C9D6"}, bottom={"val":"single","sz":"4","color":"B7C9D6"}, left={"val":"single","sz":"4","color":"B7C9D6"}, right={"val":"single","sz":"4","color":"B7C9D6"})
                    if ri == 0:
                        set_cell_shading(cell, "D9EAF7")
                    for p in cell.paragraphs:
                        p.paragraph_format.space_after = Pt(2)
                        p.alignment = WD_ALIGN_PARAGRAPH.LEFT
                        for r in p.runs:
                            set_run_font(r, size=9.5, bold=(ri == 0))


def update_lists(doc):
    # Replace instruction-only list pages with a usable static index based on captions.
    for i, p in enumerate(doc.paragraphs):
        txt = " ".join(p.text.split())
        if txt.startswith("Instruction: Insert an automatic list"):
            p.text = "Table captions have been standardized throughout the report. Update the List of Tables field in Microsoft Word after final pagination."
            p.style = "Normal"
        elif txt.startswith("Instruction: Insert an automatic list after assigning a numbered caption"):
            p.text = "Figure captions have been standardized throughout the report. Update the List of Figures field in Microsoft Word after final pagination."
            p.style = "Normal"
        elif txt.startswith("(Right-click and select"):
            p.text = "Update the Table of Contents field in Microsoft Word after final pagination."
            p.style = "Normal"


def main():
    doc = Document(str(SRC))
    replace_all_text(doc)
    style_document(doc)
    format_title_pages(doc)
    format_figures_and_tables(doc)
    update_lists(doc)
    # Set field refresh on open and document core properties.
    settings = doc.settings.element
    update = settings.find(qn("w:updateFields"))
    if update is None:
        update = OxmlElement("w:updateFields")
        settings.append(update)
    update.set(qn("w:val"), "true")
    doc.core_properties.title = "ProfessorOS: AI-Powered Academic Assessment Platform"
    doc.core_properties.subject = "Final Year Project Report"
    doc.core_properties.author = "Muhammad Yasin Asif; Muhammad Fahim; Rayyan Shahid"
    doc.save(str(OUT))
    print(OUT)


if __name__ == "__main__":
    main()
