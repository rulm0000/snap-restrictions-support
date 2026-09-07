"""Build the blinded AJPH supplement (Word) from the pipeline's current outputs.

Run AFTER 3_Tables.do and 3.1_Style tables.py, via 0_Analysis Parent File.do. Re-running this script after any data update (e.g., the weighted
re-run) rebuilds the supplement from whatever is in Results/Tables/ and
Results/Figures/ at that moment -- nothing is hard-coded from a particular run.

    python 5_Supplement.py <Results folder>

Output: Results/Supplemental_Materials.docx  (blinded: no author names in the
file or the filename, per AJPH [PREP]).

Dependencies: python-docx, openpyxl  (pip install python-docx openpyxl)
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

from docx import Document
from docx.enum.section import WD_ORIENT
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Emu, Inches, Pt
from openpyxl import load_workbook
from openpyxl.utils import range_boundaries

# ---------------------------------------------------------------------------
# CONFIG -- edit here; the build logic below should not need changes.
# ---------------------------------------------------------------------------

RESULTS = Path(sys.argv[1])
TABLES_DIR = RESULTS / "Tables"
FIGURES_DIR = RESULTS / "Figures"
OUT_PATH = RESULTS / "Supplemental_Materials.docx"

# Blinded header block (no authors, no affiliations, no IRB institution).
DOC_TITLE = "Supplemental Materials"
MANUSCRIPT_TITLE = (
    "Psychological factors associated with support for SNAP restrictions"
)

FONT = "Times New Roman"
BODY_PT = 11        # captions / notes
CELL_PT = 9         # table cells
TITLE_ROW_RE = re.compile(r"^\s*Table\s+\S+?[.:]?\s+", re.IGNORECASE)

# Tables, in supplement order. Each entry:
#   file      -- styled xlsx written by 4_Tables.do / style_tables.py
#   number    -- supplemental table number (title is re-labelled
#                "Supplemental Table N." + the xlsx's own title text,
#                so refreshed Ns / R-squared flow through automatically)
#   landscape -- True for wide tables
#   notes     -- optional note paragraph printed under the table
SUPP_TABLES = [
    # Supplemental Table 1 (exact survey items) is static text built by
    # add_items_table() below -- it has no xlsx source.
    dict(
        file=TABLES_DIR / "Table1_Descriptives.xlsx",
        number=2,
        landscape=False,
        notes="SD = standard deviation. Percentages are column percentages.",
    ),
    dict(
        file=TABLES_DIR / "Table1a_Percent_Support.xlsx",
        number=3,
        landscape=False,
        notes="SE = standard error. Support is the percent responding "
        "somewhat or strongly support.",
    ),
    dict(
        file=TABLES_DIR / "Table2_Regression.xlsx",
        number=4,
        landscape=False,
        notes="CI = confidence interval. b = unstandardized regression "
        "coefficient. Standardized effects are standardized regression "
        "coefficients (β; difference in support, in SD units, per 1-SD "
        "difference in the factor) for the continuous psychological "
        "factors, and standardized mean differences (SMD; difference vs "
        "the reference category, in SD units of support) for SNAP "
        "participation and covariates. Estimates are from a single "
        "linear regression including factor-by-SNAP interaction terms "
        "(interaction estimates shown in Supplemental Table 5); standard "
        "errors clustered by state. Bold indicates p < 0.05.",
    ),
    dict(
        file=TABLES_DIR / "Table3_Predictors_by_SNAP.xlsx",
        number=5,
        landscape=True,
        notes="CI = confidence interval. b = unstandardized regression "
        "coefficient; β = standardized regression coefficient (difference "
        "in support, in SD units, per 1-SD difference in the factor). "
        "Simple slopes and interaction p-values are from the same "
        "interaction model as Supplemental Table 4; standard errors "
        "clustered by state. Bold indicates p < 0.05.",
    ),
]

# Supplemental Table 1: exact wording of survey items (static; QRE W2 + W1 Q14)
ITEMS_TABLE_NUMBER = 1
ITEMS_TABLE_TITLE = (
    "Exact wording and response options of survey items, Numerator Consumer "
    "Panel, US adults, December 2025 and July 2026"
)
ITEMS_TABLE_SHORT = "Exact wording of survey items"
ITEMS_TABLE_NOTE = (
    "SNAP = Supplemental Nutrition Assistance Program. [SNAP] denotes the "
    "state-specific program name shown to each respondent (SNAP in most "
    "states; Food Assistance Program in AL, FL, KS, MI, and OH; Food "
    "Supplement Program in DE, ME, and MD; Food Stamps in ID and UT). All "
    "items are from the July 2026 survey except self-reported soda "
    "overconsumption, which was measured in the December 2025 survey of the "
    "same panelists. The support item appeared either early or late in the "
    "survey (randomly assigned). Perceived paternalism of SNAP policies is "
    "the mean of its two items."
)
ITEMS_ROWS = [
    ("Construct", "Survey item (exact wording)", "Response options"),
    ("SNAP participation (July 2026)",
     "In the past 3 months, did you or any member of your household receive "
     "[SNAP] benefits? This includes any [SNAP] benefits, even if the amount "
     "is small and even if benefits are received on behalf of children in "
     "the household.",
     "Yes; No; Don’t know (excluded from analysis)"),
    ("Support for SNAP restrictions (outcome; July 2026)",
     "Some states have proposed or put in place policies that remove items "
     "like soft drinks and candy from the list of things that can be bought "
     "using [SNAP] benefits. How much do you oppose or support this policy?",
     "Strongly oppose; Somewhat oppose; Neither oppose nor support; Somewhat "
     "support; Strongly support (coded 1–5; scale order randomized)"),
    ("Self-reported soda overconsumption (December 2025)",
     "Please indicate how much the next statement reflects how you typically "
     "are. “I drink soft drinks, soda, or pop more often than I "
     "should.”",
     "Not at all; Somewhat; Mostly; Definitely (coded 1–4; response "
     "order randomized)"),
    ("Perceived health risk of soda (July 2026)",
     "How much do you think drinking 1 serving of soft drinks, soda, or pop "
     "every day would increase your risk of health problems like type 2 "
     "diabetes or obesity?",
     "Not at all; Very little; Somewhat; Quite a bit; A great deal "
     "(coded 1–5)"),
    ("Felt judged when paying with SNAP — asked of SNAP recipients "
     "(July 2026)",
     "In the past 3 months, how often did you feel judged when paying for "
     "groceries with your [SNAP] benefits?",
     "Never; Rarely; Sometimes; Often; Most or all of the time (coded "
     "1–5); “I did not pay for groceries with my [SNAP] benefits "
     "in the past 3 months” (treated as missing)"),
    ("Felt judged when paying with SNAP — asked of non-recipients "
     "(July 2026)",
     "In the past 3 months, how often do you think [SNAP] participants felt "
     "judged when paying for groceries with their [SNAP] benefits?",
     "Never; Rarely; Sometimes; Often; Most or all of the time (coded "
     "1–5)"),
    ("Perceived paternalism of SNAP policies — item 1 of 2 (July 2026)",
     "The [SNAP] policies currently in place in my state are disrespectful "
     "toward people on [SNAP].",
     "Strongly disagree; Somewhat disagree; Neither disagree nor agree; "
     "Somewhat agree; Strongly agree (coded 1–5; scale order "
     "randomized)"),
    ("Perceived paternalism of SNAP policies — item 2 of 2 (July 2026)",
     "The [SNAP] policies currently in place in my state take away personal "
     "freedom.",
     "Strongly disagree; Somewhat disagree; Neither disagree nor agree; "
     "Somewhat agree; Strongly agree (coded 1–5; scale order "
     "randomized)"),
]

# Figures, in supplement order. Captions must be self-contained with
# content, place, and time (AJPH [COMP] -> Figures).
SUPP_FIGURES = [
    # The overconsumption/embarrassment panels are back in main-text
    # Figure 1 (full 4-panel restored 8/17), so they no longer appear here.
    dict(
        file=FIGURES_DIR / "fig_standardized_effects_supplement.png",
        number=1,
        title="Standardized effects of SNAP participation, psychological "
        "factors, and covariates with support for SNAP soda and candy "
        "restrictions, US adults, July 2026",
        notes="Standardized effects are standardized regression "
        "coefficients (β) for the continuous psychological factors — the "
        "difference in support, in SD units, per 1-SD increase in the "
        "factor — and standardized mean differences (SMD) vs the reference "
        "category for SNAP participation and covariates. Psychological "
        "factors do not have a reference category; their estimates are the "
        "average marginal effect across SNAP recipients and non-recipients.",
        width_in=6.0,
    ),
]

# ---------------------------------------------------------------------------
# Build logic
# ---------------------------------------------------------------------------

LETTER_W, LETTER_H = Inches(8.5), Inches(11)
MARGIN = Inches(1)


def _set_section(section, landscape: bool) -> None:
    section.orientation = WD_ORIENT.LANDSCAPE if landscape else WD_ORIENT.PORTRAIT
    section.page_width = LETTER_H if landscape else LETTER_W
    section.page_height = LETTER_W if landscape else LETTER_H
    for m in ("top_margin", "bottom_margin", "left_margin", "right_margin"):
        setattr(section, m, MARGIN)


def _para(doc, text="", *, size=BODY_PT, bold=False, italic=False,
          align=WD_ALIGN_PARAGRAPH.LEFT, space_after=6):
    p = doc.add_paragraph()
    p.alignment = align
    p.paragraph_format.space_after = Pt(space_after)
    run = p.add_run(text)
    run.font.name = FONT
    run.font.size = Pt(size)
    run.bold = bold
    run.italic = italic
    return p


def _caption(doc, label: str, title: str) -> None:
    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(6)
    r1 = p.add_run(label + " ")
    r1.font.name, r1.font.size, r1.bold = FONT, Pt(BODY_PT), True
    r2 = p.add_run(title)
    r2.font.name, r2.font.size = FONT, Pt(BODY_PT)


def _cell_border(tc_pr, edge: str, style: str | None) -> None:
    """Map an openpyxl border style onto a Word cell edge."""
    if style is None:
        return
    mapping = {
        "thin": ("single", "4"),
        "medium": ("single", "12"),
        "double": ("double", "4"),
    }
    val, sz = mapping.get(style, ("single", "4"))
    borders = tc_pr.find(qn("w:tcBorders"))
    if borders is None:
        borders = OxmlElement("w:tcBorders")
        tc_pr.append(borders)
    el = borders.find(qn(f"w:{edge}"))
    if el is None:
        el = OxmlElement(f"w:{edge}")
        borders.append(el)
    el.set(qn("w:val"), val)
    el.set(qn("w:sz"), sz)
    el.set(qn("w:color"), "000000")


def _strip_table_borders(table) -> None:
    tbl_pr = table._tbl.tblPr
    existing = tbl_pr.find(qn("w:tblBorders"))
    if existing is not None:
        tbl_pr.remove(existing)
    borders = OxmlElement("w:tblBorders")
    for edge in ("top", "left", "bottom", "right", "insideH", "insideV"):
        el = OxmlElement(f"w:{edge}")
        el.set(qn("w:val"), "none")
        el.set(qn("w:sz"), "0")
        borders.append(el)
    tbl_pr.append(borders)


def _xlsx_to_word_table(doc, xlsx_path: Path, number: int,
                        landscape: bool, notes: str) -> None:
    wb = load_workbook(xlsx_path)
    ws = wb.active

    # Extent of used range
    last_row, last_col = 1, 1
    for row in ws.iter_rows():
        for c in row:
            if c.value is not None and str(c.value).strip() != "":
                last_row = max(last_row, c.row)
                last_col = max(last_col, c.column)

    # Row 1 is the in-file title; re-label it as a supplemental caption.
    raw_title = str(ws.cell(1, 1).value or "").strip()
    title = TITLE_ROW_RE.sub("", raw_title) or raw_title
    _caption(doc, f"Supplemental Table {number}.", title)

    n_rows, n_cols = last_row - 1, last_col  # body starts at xlsx row 2
    table = doc.add_table(rows=n_rows, cols=n_cols)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    _strip_table_borders(table)

    page_w = (LETTER_H if landscape else LETTER_W) - 2 * MARGIN
    first_w = Inches(2.9) if not landscape else Inches(2.4)
    if n_cols > 1:
        other_w = Emu(int((page_w - first_w) / (n_cols - 1)))
    else:
        first_w, other_w = page_w, page_w

    for r in range(n_rows):
        xl_r = r + 2
        row = table.rows[r]
        for c in range(n_cols):
            xl_cell = ws.cell(xl_r, c + 1)
            cell = row.cells[c]
            cell.width = first_w if c == 0 else other_w

            text = "" if xl_cell.value is None else str(xl_cell.value)
            indent = len(text) - len(text.lstrip(" "))
            p = cell.paragraphs[0]
            p.paragraph_format.space_after = Pt(2)
            p.paragraph_format.space_before = Pt(2)
            if c == 0:
                p.alignment = WD_ALIGN_PARAGRAPH.LEFT
                if indent >= 2:
                    p.paragraph_format.left_indent = Inches(0.15)
            else:
                p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            run = p.add_run(text.strip())
            run.font.name = FONT
            run.font.size = Pt(CELL_PT)
            run.bold = bool(xl_cell.font and xl_cell.font.bold)
            run.italic = bool(xl_cell.font and xl_cell.font.italic)

            # Mirror the booktabs rules styled into the xlsx.
            b = xl_cell.border
            tc_pr = cell._tc.get_or_add_tcPr()
            _cell_border(tc_pr, "top", b.top.style if b and b.top else None)
            _cell_border(tc_pr, "bottom", b.bottom.style if b and b.bottom else None)
            _cell_border(tc_pr, "left", b.left.style if b and b.left else None)

    # Mirror merged ranges (skip the title row, which we replaced).
    for rng in ws.merged_cells.ranges:
        c1, r1, c2, r2 = range_boundaries(str(rng))
        if r1 == 1:
            continue
        if r2 > last_row or c2 > last_col:
            continue
        a = table.cell(r1 - 2, c1 - 1)
        bcell = table.cell(r2 - 2, c2 - 1)
        merged = a.merge(bcell)
        # Keep only the first paragraph's text after merge duplication.
        for extra in merged.paragraphs[1:]:
            if not extra.text.strip():
                extra._element.getparent().remove(extra._element)

    if notes:
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(4)
        r1 = p.add_run("Note. ")
        r1.font.name, r1.font.size, r1.italic = FONT, Pt(BODY_PT - 1), True
        r2 = p.add_run(notes)
        r2.font.name, r2.font.size = FONT, Pt(BODY_PT - 1)


def add_items_table(doc) -> None:
    """Render Supplemental Table 1 (exact survey item wording; static text)."""
    _caption(doc, f"Supplemental Table {ITEMS_TABLE_NUMBER}.", ITEMS_TABLE_TITLE)

    n_rows, n_cols = len(ITEMS_ROWS), 3
    table = doc.add_table(rows=n_rows, cols=n_cols)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    _strip_table_borders(table)

    widths = [Inches(1.6), Inches(2.9), Inches(2.0)]
    for r_i, row_vals in enumerate(ITEMS_ROWS):
        row = table.rows[r_i]
        for c_i, text in enumerate(row_vals):
            cell = row.cells[c_i]
            cell.width = widths[c_i]
            p = cell.paragraphs[0]
            p.paragraph_format.space_after = Pt(2)
            p.paragraph_format.space_before = Pt(2)
            run = p.add_run(text)
            run.font.name = FONT
            run.font.size = Pt(CELL_PT)
            run.bold = r_i == 0
            tc_pr = cell._tc.get_or_add_tcPr()
            if r_i == 0:
                _cell_border(tc_pr, "top", "medium")
                _cell_border(tc_pr, "bottom", "thin")
            elif r_i == n_rows - 1:
                _cell_border(tc_pr, "bottom", "medium")

    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(4)
    r1 = p.add_run("Note. ")
    r1.font.name, r1.font.size, r1.italic = FONT, Pt(BODY_PT - 1), True
    r2 = p.add_run(ITEMS_TABLE_NOTE)
    r2.font.name, r2.font.size = FONT, Pt(BODY_PT - 1)


def _add_figure(doc, spec: dict) -> None:
    _caption(doc, f"Supplemental Figure {spec['number']}.", spec["title"])
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = p.add_run()
    run.add_picture(str(spec["file"]), width=Inches(spec.get("width_in", 6.5)))
    if spec.get("notes"):
        pn = doc.add_paragraph()
        r1 = pn.add_run("Note. ")
        r1.font.name, r1.font.size, r1.italic = FONT, Pt(BODY_PT - 1), True
        r2 = pn.add_run(spec["notes"])
        r2.font.name, r2.font.size = FONT, Pt(BODY_PT - 1)


def main() -> int:
    tables = [t for t in SUPP_TABLES if t["file"].exists()]
    figures = [f for f in SUPP_FIGURES if f["file"].exists()]
    for t in SUPP_TABLES:
        if not t["file"].exists():
            print(f"WARNING: missing {t['file']} -- skipped")
    for f in SUPP_FIGURES:
        if not f["file"].exists():
            print(f"WARNING: missing {f['file']} -- skipped")
    if not tables and not figures:
        print("ERROR: no exhibits found; run the pipeline first (0_Master.do).")
        return 1

    doc = Document()
    doc.styles["Normal"].font.name = FONT
    doc.styles["Normal"].font.size = Pt(BODY_PT)
    _set_section(doc.sections[0], landscape=False)

    # --- Cover block (blinded) ---
    _para(doc, DOC_TITLE, size=14, bold=True,
          align=WD_ALIGN_PARAGRAPH.CENTER, space_after=10)
    _para(doc, f"Supplement to: {MANUSCRIPT_TITLE}", size=BODY_PT, italic=True,
          align=WD_ALIGN_PARAGRAPH.CENTER, space_after=16)
    _para(doc, "Contents", bold=True, space_after=4)
    _para(doc, f"Supplemental Table {ITEMS_TABLE_NUMBER}. {ITEMS_TABLE_SHORT}",
          space_after=2)
    for t in tables:
        wb = load_workbook(t["file"])
        raw = str(wb.active.cell(1, 1).value or "").strip()
        short = TITLE_ROW_RE.sub("", raw).split(",")[0]
        _para(doc, f"Supplemental Table {t['number']}. {short}",
              space_after=2)
    for f in figures:
        _para(doc, f"Supplemental Figure {f['number']}. "
              f"{f['title'].split(',')[0]}", space_after=2)

    # --- Supplemental Table 1: survey items (static) ---
    doc.add_page_break()
    add_items_table(doc)

    # --- Tables: portrait ones first in current section order ---
    current_landscape = False
    for t in tables:
        if t["landscape"] != current_landscape:
            sec = doc.add_section()
            _set_section(sec, landscape=t["landscape"])
            current_landscape = t["landscape"]
        else:
            doc.add_page_break()
        _xlsx_to_word_table(doc, t["file"], t["number"],
                            t["landscape"], t.get("notes", ""))

    # --- Figures: portrait ---
    for f in figures:
        if current_landscape:
            sec = doc.add_section()
            _set_section(sec, landscape=False)
            current_landscape = False
        else:
            doc.add_page_break()
        _add_figure(doc, f)

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    doc.save(OUT_PATH)
    print(f"Saved {OUT_PATH}")
    print(f"  {len(tables)} supplemental tables, {len(figures)} supplemental "
          f"figures. Reminder: AJPH caps supplements at 10 pages.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
