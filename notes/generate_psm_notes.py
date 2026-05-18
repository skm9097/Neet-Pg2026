#!/usr/bin/env python3
"""
PSM High-Yield Notes Generator
Question-Engraved Concept Book for NEET-PG / INICET / FMGE
"""

from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.colors import (
    HexColor, white, black, Color
)
from reportlab.lib.units import cm, mm
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_JUSTIFY, TA_RIGHT
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    PageBreak, HRFlowable, KeepTogether
)
from reportlab.platypus import ListFlowable, ListItem
from reportlab.lib import colors
import os

# ── Colour palette ──────────────────────────────────────────────────────────
C_DARK        = HexColor("#1a1a2e")   # deep navy  — headings
C_BLUE        = HexColor("#16213e")   # dark blue  — sub-headings
C_ACCENT      = HexColor("#e94560")   # red-coral  — alerts / key facts
C_TEAL        = HexColor("#0f3460")   # teal       — chapter bands
C_GOLD        = HexColor("#f5a623")   # gold       — memory hooks
C_LIGHT_BLUE  = HexColor("#dce9f5")   # light blue — question boxes
C_LIGHT_GREEN = HexColor("#d9f0e2")   # light green — answer boxes
C_LIGHT_GOLD  = HexColor("#fff7e0")   # cream      — tip boxes
C_LIGHT_RED   = HexColor("#fde8ea")   # light red  — trap boxes
C_GRAY_LIGHT  = HexColor("#f5f5f5")   # light gray — tables
C_GRAY        = HexColor("#888888")   # medium gray
C_WHITE       = white

W, H = A4  # 595.27 × 841.89 pts

# ── Document setup ──────────────────────────────────────────────────────────
OUTPUT = os.path.join(os.path.dirname(__file__), "PSM_High_Yield_Notes.pdf")

doc = SimpleDocTemplate(
    OUTPUT,
    pagesize=A4,
    leftMargin=1.8*cm, rightMargin=1.8*cm,
    topMargin=2*cm, bottomMargin=2*cm,
    title="PSM High-Yield Notes — NEET PG 2026",
    author="NEET-Pg2026 Question Bank",
)

# ── Base styles ──────────────────────────────────────────────────────────────
base = getSampleStyleSheet()

def S(name, **kw):
    return ParagraphStyle(name, **kw)

TITLE     = S("TITLE",    fontSize=28, textColor=C_WHITE,  fontName="Helvetica-Bold",
              alignment=TA_CENTER, spaceAfter=6, leading=34)
SUBTITLE  = S("SUBTITLE", fontSize=14, textColor=HexColor("#c8d6e5"),
              fontName="Helvetica", alignment=TA_CENTER, spaceAfter=4)
TAGLINE   = S("TAGLINE",  fontSize=11, textColor=HexColor("#aaa"),
              fontName="Helvetica-Oblique", alignment=TA_CENTER, spaceAfter=12)

CH_TITLE  = S("CH_TITLE", fontSize=20, textColor=C_WHITE,
              fontName="Helvetica-Bold", alignment=TA_LEFT, leading=24, spaceAfter=4)
CH_SUB    = S("CH_SUB",   fontSize=12, textColor=HexColor("#c8d6e5"),
              fontName="Helvetica-Oblique", alignment=TA_LEFT, spaceAfter=8)

H1        = S("H1",       fontSize=14, textColor=C_DARK,   fontName="Helvetica-Bold",
              spaceBefore=10, spaceAfter=4, leading=18)
H2        = S("H2",       fontSize=12, textColor=C_TEAL,   fontName="Helvetica-Bold",
              spaceBefore=8, spaceAfter=3, leading=15)
H3        = S("H3",       fontSize=11, textColor=C_BLUE,   fontName="Helvetica-Bold",
              spaceBefore=6, spaceAfter=2, leading=14)

BODY      = S("BODY",     fontSize=10, textColor=black,    fontName="Helvetica",
              leading=14, spaceAfter=4, alignment=TA_JUSTIFY)
BODY_SM   = S("BODY_SM",  fontSize=9,  textColor=black,    fontName="Helvetica",
              leading=13, spaceAfter=3)
BOLD      = S("BOLD",     fontSize=10, textColor=black,    fontName="Helvetica-Bold",
              leading=14, spaceAfter=2)
ITALIC    = S("ITALIC",   fontSize=10, textColor=HexColor("#444"),
              fontName="Helvetica-Oblique", leading=14, spaceAfter=3)

Q_STEM    = S("Q_STEM",   fontSize=10, textColor=C_DARK,   fontName="Helvetica-Bold",
              leading=14, spaceAfter=3, leftIndent=4)
Q_OPT     = S("Q_OPT",    fontSize=9.5,textColor=black,    fontName="Helvetica",
              leading=13, spaceAfter=1, leftIndent=12)
A_TEXT    = S("A_TEXT",   fontSize=10, textColor=HexColor("#1a5c2a"),
              fontName="Helvetica-Bold", leading=14, spaceAfter=2, leftIndent=4)
A_EXPLAIN = S("A_EXPLAIN",fontSize=9.5,textColor=HexColor("#2d4e2d"),
              fontName="Helvetica", leading=13, spaceAfter=4, leftIndent=4)

TIP_HEAD  = S("TIP_HEAD", fontSize=10, textColor=HexColor("#7d5a00"),
              fontName="Helvetica-Bold", leading=14, spaceAfter=2)
TIP_BODY  = S("TIP_BODY", fontSize=9.5,textColor=HexColor("#5a4000"),
              fontName="Helvetica", leading=13, spaceAfter=3)

TRAP_HEAD = S("TRAP_HEAD",fontSize=10, textColor=HexColor("#8b0000"),
              fontName="Helvetica-Bold", leading=14, spaceAfter=2)
TRAP_BODY = S("TRAP_BODY",fontSize=9.5,textColor=HexColor("#5a0000"),
              fontName="Helvetica", leading=13, spaceAfter=3)

REV_HEAD  = S("REV_HEAD", fontSize=11, textColor=C_TEAL,   fontName="Helvetica-Bold",
              spaceBefore=6, spaceAfter=3)
REV_ITEM  = S("REV_ITEM", fontSize=9.5,textColor=C_DARK,   fontName="Helvetica",
              leading=13, spaceAfter=1, leftIndent=8,
              bulletIndent=2, bulletFontName="Helvetica", bulletFontSize=9)
FOOTER    = S("FOOTER",   fontSize=8,  textColor=C_GRAY,   fontName="Helvetica",
              alignment=TA_CENTER)

# ── Helper builders ──────────────────────────────────────────────────────────
def hr(color=C_TEAL, thickness=0.5, spaceB=4, spaceA=4):
    return HRFlowable(width="100%", thickness=thickness, color=color,
                      spaceAfter=spaceA, spaceBefore=spaceB)

def vspace(h=6):
    return Spacer(1, h)

def colored_box(content_rows, bg=C_LIGHT_BLUE, border=C_TEAL, padding=6):
    tbl = Table([[c] for c in content_rows], colWidths=[W - 3.6*cm])
    style = TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), bg),
        ('BOX',        (0,0), (-1,-1), 0.8, border),
        ('TOPPADDING', (0,0), (-1,-1), padding),
        ('BOTTOMPADDING',(0,0),(-1,-1), padding),
        ('LEFTPADDING', (0,0), (-1,-1), padding+2),
        ('RIGHTPADDING',(0,0),(-1,-1), padding),
    ])
    tbl.setStyle(style)
    return tbl

def question_box(stem, opts, answer, explanation):
    rows = [Paragraph(f"Q: {stem}", Q_STEM)]
    for o in opts:
        rows.append(Paragraph(o, Q_OPT))
    rows.append(vspace(3))
    rows.append(Paragraph(f"✓ {answer}", A_TEXT))
    rows.append(Paragraph(explanation, A_EXPLAIN))
    return colored_box(rows, bg=C_LIGHT_BLUE, border=C_TEAL)

def tip_box(head, body):
    rows = [Paragraph(f"💡 {head}", TIP_HEAD), Paragraph(body, TIP_BODY)]
    return colored_box(rows, bg=C_LIGHT_GOLD, border=C_GOLD)

def trap_box(head, body):
    rows = [Paragraph(f"⚠ {head}", TRAP_HEAD), Paragraph(body, TRAP_BODY)]
    return colored_box(rows, bg=C_LIGHT_RED, border=C_ACCENT)

def memory_box(head, body):
    rows = [Paragraph(f"🧠 {head}", TIP_HEAD), Paragraph(body, TIP_BODY)]
    return colored_box(rows, bg=HexColor("#f0e6ff"), border=HexColor("#7b2d8b"))

def chapter_header(num, title, subtitle):
    tbl = Table([[
        Paragraph(f"Chapter {num}", S("chnum", fontSize=10, textColor=HexColor("#aec6e8"),
                  fontName="Helvetica-Bold")),
        ""
    ],[
        Paragraph(title, CH_TITLE),
        ""
    ],[
        Paragraph(subtitle, CH_SUB),
        ""
    ]], colWidths=[W - 3.6*cm, 0])
    tbl.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), C_TEAL),
        ('TOPPADDING', (0,0), (-1,-1), 8),
        ('BOTTOMPADDING',(0,0),(-1,-1), 8),
        ('LEFTPADDING', (0,0), (-1,-1), 12),
        ('RIGHTPADDING',(0,0),(-1,-1), 8),
        ('SPAN', (0,0), (1,0)),
        ('SPAN', (0,1), (1,1)),
        ('SPAN', (0,2), (1,2)),
    ]))
    return KeepTogether([tbl, vspace(8)])

def two_col_table(data, headers=None, col_widths=None):
    available = W - 3.6*cm
    if col_widths is None:
        col_widths = [available*0.45, available*0.55]
    rows = []
    if headers:
        rows.append([Paragraph(f"<b>{h}</b>", BODY_SM) for h in headers])
    for row in data:
        rows.append([Paragraph(str(c), BODY_SM) for c in row])
    tbl = Table(rows, colWidths=col_widths)
    style = [
        ('BACKGROUND', (0,0), (-1,0), C_TEAL),
        ('TEXTCOLOR',  (0,0), (-1,0), C_WHITE),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [C_GRAY_LIGHT, C_WHITE]),
        ('BOX',        (0,0), (-1,-1), 0.5, C_GRAY),
        ('INNERGRID',  (0,0), (-1,-1), 0.3, HexColor("#dddddd")),
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('BOTTOMPADDING',(0,0),(-1,-1), 4),
        ('LEFTPADDING', (0,0), (-1,-1), 5),
        ('RIGHTPADDING',(0,0),(-1,-1), 5),
    ]
    if not headers:
        style[0] = ('BACKGROUND', (0,0), (0,-1), C_LIGHT_BLUE)
    tbl.setStyle(TableStyle(style))
    return tbl

def revision_capsule(items):
    rows = [Paragraph("⚡ ULTRA HIGH-YIELD REVISION CAPSULE", REV_HEAD)]
    for item in items:
        rows.append(Paragraph(f"• {item}", REV_ITEM))
    return colored_box(rows, bg=HexColor("#e8f4ff"), border=C_TEAL, padding=8)

# ── Page callbacks ───────────────────────────────────────────────────────────
def on_page(canvas, doc):
    canvas.saveState()
    page = doc.page
    if page > 2:
        canvas.setFillColor(C_GRAY)
        canvas.setFont("Helvetica", 8)
        canvas.drawString(1.8*cm, 1.2*cm, "PSM High-Yield Notes — NEET PG 2026")
        canvas.drawRightString(W - 1.8*cm, 1.2*cm, f"Page {page}")
        canvas.setStrokeColor(HexColor("#dddddd"))
        canvas.setLineWidth(0.5)
        canvas.line(1.8*cm, 1.5*cm, W - 1.8*cm, 1.5*cm)
    canvas.restoreState()

# ============================================================================
# CONTENT
# ============================================================================

story = []

# ── COVER ────────────────────────────────────────────────────────────────────
cover_bg = Table([[""]],
    colWidths=[W - 3.6*cm],
    rowHeights=[H - 4*cm])
cover_bg.setStyle(TableStyle([
    ('BACKGROUND', (0,0), (0,0), C_DARK),
    ('TOPPADDING', (0,0), (0,0), 0),
    ('BOTTOMPADDING', (0,0), (0,0), 0),
]))

story.append(vspace(40))
story.append(Paragraph("PSM", S("cov1", fontSize=60, textColor=C_ACCENT,
    fontName="Helvetica-Bold", alignment=TA_CENTER, leading=64)))
story.append(Paragraph("HIGH-YIELD NOTES", TITLE))
story.append(vspace(8))
story.append(Paragraph("Question-Engraved Concept Book", SUBTITLE))
story.append(Paragraph("NEET PG · INICET · FMGE · UPSC CMS", TAGLINE))
story.append(vspace(20))

story.append(colored_box([
    Paragraph("📚 Based on 260+ PYQs • 2015–2025 • 10 High-Yield Chapters", S(
        "cov2", fontSize=11, textColor=C_TEAL, fontName="Helvetica-Bold",
        alignment=TA_CENTER, leading=16)),
    Paragraph("Concepts emerge from questions. Patterns replace memorization.", S(
        "cov3", fontSize=10, textColor=HexColor("#555"), fontName="Helvetica-Oblique",
        alignment=TA_CENTER, leading=14)),
], bg=HexColor("#eef4fb"), border=C_TEAL, padding=10))

story.append(vspace(30))
story.append(Paragraph("Preventive & Social Medicine (PSM / Community Medicine)",
    S("cov4", fontSize=10, textColor=C_GRAY, fontName="Helvetica-Oblique",
      alignment=TA_CENTER)))
story.append(PageBreak())

# ── HOW TO USE THIS BOOK ─────────────────────────────────────────────────────
story.append(Paragraph("How To Use This Book", H1))
story.append(hr())
story.append(Paragraph(
    "This is NOT a textbook. This is a <b>Question-Engraved Concept Book</b>. "
    "Every concept grows <i>out of</i> questions — not beside them. "
    "As you read, you will repeatedly feel: <b>'Now I understand WHY the examiner asked this.'</b>",
    BODY))
story.append(vspace(4))

story.append(two_col_table([
    ["📖 First read", "Read each chapter as a narrative. Don't skip the traps section."],
    ["🔄 Second pass", "Cover answers, attempt questions, then compare your reasoning."],
    ["⚡ Rapid revision", "Use only the Revision Capsule at each chapter end."],
    ["🎯 Exam day", "Re-read only the Trap Alerts and Memory Hooks."],
], headers=["Usage Mode", "Instructions"]))

story.append(vspace(8))
story.append(tip_box("The Secret of High Scorers",
    "High scorers don't memorise more — they understand patterns. "
    "Every PSM PYQ in the last 8 years fits ≤15 core conceptual clusters. "
    "This book maps all of them. Once you see the patterns, you stop fearing PSM."))
story.append(PageBreak())

# ── TABLE OF CONTENTS ────────────────────────────────────────────────────────
story.append(Paragraph("Contents", H1))
story.append(hr())
toc_data = [
    ["1", "Biostatistics — The Examiner's Playground", "5"],
    ["2", "Epidemiology & Study Designs", "13"],
    ["3", "Screening & Levels of Prevention", "20"],
    ["4", "Communicable Disease Control", "28"],
    ["5", "Immunization & Cold Chain", "36"],
    ["6", "National Health Programs", "43"],
    ["7", "Environmental & Occupational Health", "49"],
    ["8", "Health Administration & Infrastructure", "56"],
    ["9", "Nutrition, Demography & Vital Statistics", "62"],
    ["10", "Health Indicators & International Health", "70"],
]
avail = W - 3.6*cm
toc_tbl = Table(toc_data, colWidths=[avail*0.06, avail*0.80, avail*0.14])
toc_tbl.setStyle(TableStyle([
    ('ROWBACKGROUNDS', (0,0), (-1,-1), [C_GRAY_LIGHT, C_WHITE]),
    ('BOX', (0,0),(-1,-1),0.3,C_GRAY),
    ('INNERGRID',(0,0),(-1,-1),0.2,HexColor("#eeeeee")),
    ('TOPPADDING',(0,0),(-1,-1),5),
    ('BOTTOMPADDING',(0,0),(-1,-1),5),
    ('LEFTPADDING',(0,0),(-1,-1),6),
    ('FONTNAME',(0,0),(0,-1),"Helvetica-Bold"),
    ('FONTNAME',(2,0),(2,-1),"Helvetica-Bold"),
    ('TEXTCOLOR',(0,0),(0,-1),C_TEAL),
    ('ALIGN',(2,0),(2,-1),"RIGHT"),
]))
story.append(toc_tbl)
story.append(PageBreak())

# ============================================================================
# CHAPTER 1 — BIOSTATISTICS
# ============================================================================
story.append(chapter_header(1, "Biostatistics", "The Examiner's Playground — 30+ Questions in 8 Years"))

story.append(Paragraph("🎯 What the Examiner REALLY Targets", H2))
story.append(Paragraph(
    "Biostatistics is the single most tested PSM sub-topic. The examiner doesn't test "
    "formula derivations — they test your ability to <b>choose the right tool</b> for a "
    "given data scenario. The four most-repeated decision points are: "
    "(1) which test to use, (2) what SD/distribution tells you, "
    "(3) how to read screening test calculations, and (4) how to define bias.",
    BODY))
story.append(vspace(4))

story.append(Paragraph("Core Concept 1: Choosing the Right Statistical Test", H2))
story.append(Paragraph(
    "Think of statistical tests as <i>tools for different jobs</i>. "
    "The examiner gives you a scenario and expects you to identify which tool fits. "
    "The decision tree is simple once you internalize one rule: "
    "<b>First ask: what kind of data is this?</b>",
    BODY))

story.append(vspace(4))
story.append(two_col_table([
    ["Two independent group <b>means</b> (continuous data)", "<b>Unpaired T-test</b>"],
    ["Same group before & after (continuous)", "<b>Paired T-test</b>"],
    ["Comparing proportions / categorical data", "<b>Chi-square (χ²) test</b>"],
    ["≥ 3 group means (continuous)", "<b>ANOVA (F-test)</b>"],
    ["Predict one variable from another", "<b>Regression coefficient</b>"],
    ["Measure strength of association", "<b>Correlation coefficient (r)</b>"],
    ["Compare variability between datasets", "<b>Coefficient of Variation (CV)</b>"],
    ["Non-parametric data (ordinal/skewed)", "<b>Mann-Whitney U / Kruskal-Wallis</b>"],
], headers=["Scenario", "Correct Test"], col_widths=[(W-3.6*cm)*0.55, (W-3.6*cm)*0.45]))

story.append(vspace(6))
story.append(question_box(
    "A study assesses malnutrition in rural (30/100 malnourished) and urban (20/100). Which test?",
    ["A. Paired t-test", "B. Chi-square", "C. Unpaired t-test", "D. ANOVA"],
    "B. Chi-square",
    "The data is PROPORTIONS (malnourished vs not) in two INDEPENDENT groups. "
    "Proportions/categorical data → Chi-square. Trap: students pick t-test because "
    "two groups are mentioned — but t-test is for MEANS (continuous data), not proportions. "
    "Paired t-test = same group before/after. This is rural vs urban = independent groups."
))
story.append(vspace(4))
story.append(question_box(
    "To compare haemoglobin levels between two independent groups, which test is used?",
    ["A. Chi-square", "B. Unpaired t-test", "C. Paired t-test", "D. ANOVA"],
    "B. Unpaired t-test",
    "Haemoglobin is a CONTINUOUS variable. Two INDEPENDENT groups = Unpaired t-test. "
    "Paired t-test = would be used if the SAME patients had Hb measured before and after treatment. "
    "Chi-square = categorical data only (e.g., anaemic vs not)."
))
story.append(vspace(6))

story.append(trap_box("The t-test vs Chi-square Trap",
    "The #1 biostatistics trap: When you see 'two groups,' students instinctively jump to t-test. "
    "STOP. Ask: 'What is being compared — MEANS or PROPORTIONS?' "
    "Proportions, percentages, counts, categorical data → Chi-square ALWAYS."))

story.append(vspace(6))
story.append(Paragraph("Core Concept 2: Normal Distribution & Standard Deviation", H2))
story.append(Paragraph(
    "The normal (bell) curve is symmetric. In a normal distribution, mean = median = mode. "
    "The <b>68-95-99.7 rule</b> is tested almost every year in some form.",
    BODY))
story.append(two_col_table([
    ["Mean ± 1 SD", "68% of values"],
    ["Mean ± 2 SD", "95% of values (95.4%)"],
    ["Mean ± 3 SD", "99.7% of values"],
    ["Beyond 2 SD", "Statistically significant (p < 0.05)"],
    ["Skewed right", "Mean > Median > Mode"],
    ["Skewed left", "Mean < Median < Mode"],
    ["Best central tendency in skewed data", "Median (not affected by outliers)"],
], headers=["Fact", "Value / Interpretation"]))

story.append(vspace(6))
story.append(question_box(
    "A study has mean = 200, SD = 20. 68% of values lie between:",
    ["A. 160–240", "B. 170–230", "C. 180–220", "D. 190–210"],
    "C. 180–220",
    "Mean ± 1 SD = 200 ± 20 = 180–220 (68%). "
    "Mean ± 2 SD = 200 ± 40 = 160–240 (95%). "
    "Mean ± 0.5 SD = 200 ± 10 = 190–210 (38%). "
    "Trap: Option A (160–240) looks like '2 SD range' and many select it confused by the question asking for 68%."
))
story.append(vspace(6))

story.append(Paragraph("Core Concept 3: Screening Tests — PPV, NPV, Sensitivity, Specificity", H2))
story.append(Paragraph(
    "This is the most calculation-intensive area. "
    "The key is to <b>always draw the 2×2 table</b> before solving. "
    "Never try to solve from memory alone.",
    BODY))

avail = W - 3.6*cm
tbl_2x2 = Table([
    ["", Paragraph("<b>Disease +</b>", BODY_SM), Paragraph("<b>Disease −</b>", BODY_SM), Paragraph("<b>Total</b>", BODY_SM)],
    [Paragraph("<b>Test +</b>", BODY_SM), Paragraph("TP (a)", BODY_SM), Paragraph("FP (b)", BODY_SM), Paragraph("a+b", BODY_SM)],
    [Paragraph("<b>Test −</b>", BODY_SM), Paragraph("FN (c)", BODY_SM), Paragraph("TN (d)", BODY_SM), Paragraph("c+d", BODY_SM)],
    [Paragraph("<b>Total</b>", BODY_SM), Paragraph("a+c", BODY_SM), Paragraph("b+d", BODY_SM), ""],
], colWidths=[avail*0.18, avail*0.22, avail*0.22, avail*0.18])
tbl_2x2.setStyle(TableStyle([
    ('BACKGROUND',(0,0),(3,0),C_TEAL), ('TEXTCOLOR',(0,0),(3,0),C_WHITE),
    ('BACKGROUND',(0,1),(0,3),C_LIGHT_BLUE),
    ('BOX',(0,0),(-1,-1),0.8,C_TEAL),
    ('INNERGRID',(0,0),(-1,-1),0.4,C_GRAY),
    ('ALIGN',(0,0),(-1,-1),"CENTER"),
    ('TOPPADDING',(0,0),(-1,-1),4), ('BOTTOMPADDING',(0,0),(-1,-1),4),
]))
story.append(tbl_2x2)
story.append(vspace(5))

story.append(two_col_table([
    ["Sensitivity", "TP/(TP+FN) — detects true positives"],
    ["Specificity", "TN/(TN+FP) — rules out true negatives"],
    ["PPV", "TP/(TP+FP) — if test +ve, chance of disease"],
    ["NPV", "TN/(TN+FN) — if test −ve, chance of no disease"],
    ["Sensitivity ↑ with", "Low cut-off / wide net — more FP, fewer FN"],
    ["Specificity ↑ with", "High cut-off / strict criteria — more FN, fewer FP"],
    ["PPV depends on", "Prevalence (PPV ↑ when prevalence ↑)"],
    ["NPV depends on", "Prevalence (NPV ↑ when prevalence ↓)"],
], headers=["Measure", "Definition / Key Fact"]))

story.append(vspace(6))
story.append(question_box(
    "CA-125 screen for ovarian CA: 60/100 test-positive had disease; 20/100 test-negative had disease. NPV?",
    ["A. 20/100", "B. 40/100", "C. 60/100", "D. 80/100"],
    "D. 80/100",
    "Build the 2×2 table: TP=60, FP=40, FN=20, TN=80. "
    "NPV = TN/(TN+FN) = 80/(80+20) = 80%. "
    "Trap: Many select 60/100 (the PPV) or 20/100 (the FN rate). "
    "Always remember NPV is about those who tested NEGATIVE — 80 out of 100 negatives truly don't have disease."
))
story.append(vspace(6))

story.append(Paragraph("Core Concept 4: Types of Bias", H2))
story.append(Paragraph(
    "Bias = systematic error. The examiner asks you to identify bias from a scenario. "
    "The trick is each bias has ONE unique feature that no other bias has.",
    BODY))

story.append(two_col_table([
    ["<b>Berkson's (Admission Rate) Bias</b>", "Hospital-based study; people with TWO diseases over-represented"],
    ["<b>Lead Time Bias</b>", "Screening finds disease early → survival APPEARS longer, but mortality unchanged"],
    ["<b>Length Bias</b>", "Screening catches slow-growing (less lethal) tumours more than fast-growing ones"],
    ["<b>Neyman (Incidence-Prevalence) Bias</b>", "Fatal/short-duration cases missed in prevalence studies"],
    ["<b>Recall Bias</b>", "Cases remember exposure better than controls (case-control studies)"],
    ["<b>Volunteer Bias</b>", "Volunteers are healthier/more motivated than non-volunteers"],
    ["<b>Observer Bias</b>", "Researcher's expectation influences measurement"],
    ["<b>Confounding Bias</b>", "Third variable associated with BOTH exposure and outcome — distorts association"],
], headers=["Bias Type", "Defining Feature"]))

story.append(vspace(6))
story.append(question_box(
    "In a hospital study, patients with both breast cancer AND meningioma are more likely to be admitted than those with either alone. This inflates the apparent association. Which bias?",
    ["A. Lead time bias", "B. Berkson's bias", "C. Neyman bias", "D. Recall bias"],
    "B. Berkson's (Admission Rate) bias",
    "Berkson's bias = HOSPITAL-BASED studies where people with 2 diseases (exposure + outcome) "
    "are MORE likely to be hospitalised → inflated association. "
    "Key: If the question says 'hospital-based case-control' + 'dual pathology over-admission' → Berkson's."
))
story.append(vspace(4))
story.append(question_box(
    "Screening detects cancer at Stage I instead of Stage III. Five-year survival improves, but mortality rate doesn't change. This is an example of:",
    ["A. Length bias", "B. Selection bias", "C. Lead time bias", "D. Observer bias"],
    "C. Lead time bias",
    "Lead time = the interval between early detection and the time diagnosis would have been made clinically. "
    "Survival appears improved because the clock starts earlier — not because the disease course changed. "
    "The confirming clue is: 'mortality didn't change.' If mortality changed, it would be a true benefit."
))
story.append(vspace(6))

story.append(trap_box("Confounding vs Effect Modification",
    "Confounding: A third variable distorts the exposure-disease relationship. "
    "It is ASSOCIATED with both exposure and outcome AND unequally distributed. "
    "Trap: If the question says 'equally distributed' → NOT a confounder (it cancels out). "
    "Key definiton: 'Associated with BOTH exposure AND disease, distributed UNEQUALLY.'"))

story.append(vspace(6))
story.append(Paragraph("Core Concept 5: p-value, Null Hypothesis, and Statistical Significance", H2))
story.append(Paragraph(
    "The p-value is the probability of getting your result IF the null hypothesis is true. "
    "<b>p &lt; 0.05 = statistically significant</b> = reject null hypothesis. "
    "This does NOT mean clinical significance.",
    BODY))
story.append(tip_box("Reading p-values in MCQs",
    "When a question says 'p = 0.03' → significant, reject H₀, the groups ARE different. "
    "When 'p = 0.08' → NOT significant, cannot reject H₀. "
    "Examiner trap: 'p < 0.05 means the result is clinically important' — FALSE. "
    "Statistical significance ≠ clinical significance."))

story.append(vspace(6))
story.append(revision_capsule([
    "Chi-square = categorical/proportions | Unpaired T = two independent means | Paired T = before-after means",
    "68%-95%-99.7% rule: ±1SD, ±2SD, ±3SD",
    "Skewed data → Median is best central tendency",
    "NPV = TN/(TN+FN) | PPV = TP/(TP+FP) | Sensitivity = TP/(TP+FN) | Specificity = TN/(TN+FP)",
    "PPV ↑ with prevalence ↑ | NPV ↑ with prevalence ↓ (sensitivity/specificity don't change with prevalence)",
    "Berkson's = hospital + 2 diseases | Lead time = early detection + no mortality change",
    "Confounding = associated with BOTH + distributed UNEQUALLY",
    "p < 0.05 = reject null hypothesis = statistically significant",
    "Coefficient of Variation (CV) = compare variability between datasets with different units",
    "Coefficient of regression = predict one variable FROM another",
]))
story.append(PageBreak())

# ============================================================================
# CHAPTER 2 — EPIDEMIOLOGY & STUDY DESIGNS
# ============================================================================
story.append(chapter_header(2, "Epidemiology & Study Designs",
    "Which Study for Which Purpose — A Decision Framework"))

story.append(Paragraph("🎯 What the Examiner Targets", H2))
story.append(Paragraph(
    "The examiner gives you a research SCENARIO and asks you to identify the study design. "
    "The key to every question is: <b>What is the unit of analysis — individual or population? "
    "And in which direction does time flow?</b>",
    BODY))

story.append(vspace(4))
story.append(two_col_table([
    ["Exposure → Disease (present to future)", "<b>Cohort study</b> → Relative Risk (RR)"],
    ["Disease → Look back at exposure", "<b>Case-control</b> → Odds Ratio (OR)"],
    ["Both exposure & disease measured NOW", "<b>Cross-sectional</b> → Prevalence"],
    ["Aggregate data (regions/time periods)", "<b>Ecological</b> → Risk of ecological fallacy"],
    ["Intervention assigned by investigator", "<b>Experimental (RCT)</b>"],
    ["Natural experiment / assigned by nature", "<b>Quasi-experimental</b>"],
    ["Individual followed over time from past", "<b>Retrospective cohort</b>"],
], headers=["Time Direction / Design Feature", "Study Type"]))

story.append(vspace(6))
story.append(question_box(
    "A researcher collects lung cancer death data from hospitals and cigarette sales from the taxation dept in the same period. What study type?",
    ["A. Cross-sectional", "B. Ecological", "C. Cohort", "D. Case-control"],
    "B. Ecological study",
    "KEY: The data is aggregate/group-level (population-level cancer rates vs population-level cigarette sales). "
    "No individual-level data is collected. Unit of analysis = population (not individuals) → Ecological. "
    "Warning: ecological studies are subject to ECOLOGICAL FALLACY — a relationship seen at population level "
    "may not hold at the individual level."
))
story.append(vspace(4))
story.append(question_box(
    "Doctors in 1970 were asked about their smoking habits. They are followed until 2000 to record lung cancer occurrence. Design?",
    ["A. Case-control", "B. Cross-sectional", "C. Prospective cohort", "D. Retrospective cohort"],
    "C. Prospective cohort",
    "Exposure (smoking) identified FIRST, then followed forward in time for outcome (lung cancer). "
    "This is the classic PROSPECTIVE COHORT design (Doll & Hill study). "
    "Generates: Relative Risk (RR), Attributable Risk (AR). "
    "Retrospective cohort = exposure data collected from PAST records, then outcome tracked."
))
story.append(vspace(6))

story.append(Paragraph("Measures of Association: RR, OR, AR", H2))
story.append(two_col_table([
    ["<b>Relative Risk (RR)</b>", "Cohort study. Risk in exposed / Risk in unexposed"],
    ["<b>Odds Ratio (OR)</b>", "Case-control. Cross-product ratio (ad/bc). ≈ RR when disease is rare"],
    ["<b>Attributable Risk (AR)</b>", "Incidence exposed − Incidence unexposed. Absolute excess risk"],
    ["<b>Population AR (PAR)</b>", "Incidence total − Incidence unexposed. Public health importance"],
    ["<b>NNT</b>", "1/ARR. Number needed to treat to prevent one outcome"],
], headers=["Measure", "Study + Formula / Use"]))

story.append(vspace(6))
story.append(question_box(
    "Cross-product ratio (Odds Ratio) is obtained from:",
    ["A. Ecological study", "B. Cohort study", "C. Cross-sectional", "D. Case-control"],
    "D. Case-control study",
    "OR = (a×d)/(b×c) from a 2×2 table. Used in CASE-CONTROL studies because you start with "
    "disease status (cases vs controls) and look backwards at exposure. "
    "Trap: Some say 'OR can be calculated from a cohort study too' — TRUE, but the question asks "
    "about the PRIMARY measure from case-control studies. OR ≈ RR only when disease prevalence is low (<10%)."
))
story.append(vspace(6))

story.append(Paragraph("Confounding — The Full Picture", H2))
story.append(Paragraph(
    "A confounder is a variable that creates a false association between exposure and disease. "
    "It must satisfy THREE criteria: (1) Associated with the EXPOSURE, (2) Associated with the DISEASE "
    "(independent of exposure), and (3) NOT on the causal pathway between exposure and disease.",
    BODY))
story.append(question_box(
    "A confounding factor is defined as one which is associated with:",
    ["A. Exposure only, distributed unequally",
     "B. Both exposure AND disease, distributed unequally",
     "C. Both exposure AND disease, distributed equally",
     "D. Disease only, distributed unequally"],
    "B. Associated with BOTH exposure and disease, distributed UNEQUALLY",
    "ALL three words matter: (1) BOTH = it must link to exposure AND disease. "
    "(2) UNEQUALLY = if it were equally distributed between groups, it would cancel out and not confound. "
    "Trap: Option C has 'equally' distributed — that would NOT cause confounding. "
    "Option A says 'exposure only' — that's just a risk marker, not a confounder."
))
story.append(vspace(6))

story.append(Paragraph("Surveillance: Types and Purpose", H2))
story.append(two_col_table([
    ["<b>Active surveillance</b>", "Health workers actively search for cases (field visits, phone calls)"],
    ["<b>Passive surveillance</b>", "Routine spontaneous reporting by providers to health authorities"],
    ["<b>Sentinel surveillance</b>", "Selected high-quality reporting sites monitor trends in specific populations"],
    ["<b>Syndromic surveillance</b>", "Monitor non-specific symptoms (ED visits, OTC sales) for early outbreak signal"],
    ["<b>Surveillance objective</b>", "Detect outbreaks/trends EARLY for timely public health response"],
    ["<b>Monitoring</b>", "Routine, continuous measurement of programme inputs/outputs (≠ surveillance)"],
], headers=["Type", "Key Feature"]))

story.append(vspace(6))
story.append(revision_capsule([
    "Cohort → RR | Case-control → OR | Cross-sectional → Prevalence",
    "Ecological = population-level data, risk of ecological fallacy",
    "Prospective cohort = exposure identified FIRST, followed forward",
    "Retrospective cohort = exposure from PAST records, outcome from records",
    "OR ≈ RR when disease prevalence < 10% (rare disease assumption)",
    "Confounder: associated with BOTH + unequally distributed",
    "Attributable Risk = Incidence(exposed) − Incidence(unexposed)",
    "Active surveillance = health workers search actively",
    "Passive surveillance = routine reporting by providers",
    "Sentinel surveillance = selected sites monitoring specific populations",
]))
story.append(PageBreak())

# ============================================================================
# CHAPTER 3 — SCREENING & LEVELS OF PREVENTION
# ============================================================================
story.append(chapter_header(3, "Screening & Levels of Prevention",
    "Leavell & Clark's Framework — Tested Every Year, Multiple Angles"))

story.append(Paragraph("🎯 What the Examiner Targets", H2))
story.append(Paragraph(
    "This is the second most-repeated PSM conceptual cluster. "
    "The examiner tests you in two ways: (1) Give a clinical intervention and ask which LEVEL of prevention, "
    "and (2) Give a screening scenario and ask about validity/test properties. "
    "Both require a firm conceptual map, not memorisation.",
    BODY))

story.append(vspace(4))
story.append(Paragraph("The 5 Levels of Prevention (Leavell & Clark)", H2))
story.append(two_col_table([
    ["<b>Primordial Prevention</b>", "Prevent risk factors from emerging in the population (e.g., tobacco-free generation, healthy school lunch policies)"],
    ["<b>Primary Prevention Level 1: Health Promotion</b>", "General health improvement not targeting a specific disease (e.g., sanitary latrines, adequate nutrition, health education)"],
    ["<b>Primary Prevention Level 2: Specific Protection</b>", "Protection against a specific disease (e.g., immunisation, OCP, seatbelt use, iodised salt, fluoride)"],
    ["<b>Secondary Prevention: Early Diagnosis & Treatment</b>", "Screening tests, clinical examination to detect pre-symptomatic disease. Reduce severity/duration."],
    ["<b>Tertiary Prevention: Disability Limitation</b>", "Prevent worsening/disability in established disease (e.g., callipers in polio, preventing limb loss in diabetes)"],
    ["<b>Tertiary Prevention: Rehabilitation</b>", "Restore function after disability (physiotherapy, prosthetics, vocational rehab)"],
], headers=["Level", "Definition & Examples"],
col_widths=[(W-3.6*cm)*0.35, (W-3.6*cm)*0.65]))

story.append(vspace(6))
story.append(question_box(
    "Vitamin A prophylaxis in children is which level of prevention?",
    ["A. Primordial", "B. Specific protection (Primary)", "C. Early diagnosis", "D. Disability limitation"],
    "B. Specific protection (Primary Prevention Level 2)",
    "Vitamin A prophylaxis prevents a SPECIFIC disease (Vitamin A deficiency / xerophthalmia). "
    "Any intervention that prevents a specific condition = Specific Protection. "
    "Contrast: Balanced diet (general nutrition) = Health Promotion. Vitamin A treatment for a deficient child = Disability Limitation."
))
story.append(vspace(4))
story.append(question_box(
    "Providing callipers (leg braces) to a child with poliomyelitis. Level of prevention?",
    ["A. Health promotion", "B. Specific protection", "C. Disability limitation", "D. Rehabilitation"],
    "C. Disability limitation",
    "The disease (polio) has already occurred and caused damage. "
    "Callipers PREVENT FURTHER DISABILITY from the existing disease. "
    "Disability limitation = preventing worsening of existing disease. "
    "Rehabilitation = RESTORING function. Callipers support function but don't restore it."
))
story.append(vspace(4))
story.append(question_box(
    "Seatbelt use while driving. Level of prevention?",
    ["A. Primordial", "B. Health promotion", "C. Specific protection", "D. Early diagnosis"],
    "C. Specific protection",
    "Seatbelt targets SPECIFIC protection against road traffic injury. "
    "Common trap: students say 'health promotion' because it seems general. "
    "Key rule: if it targets a SPECIFIC hazard → Specific Protection. "
    "Primordial = prevent the risk factor from emerging at population level (e.g., policy banning drunk driving)."
))
story.append(vspace(6))

story.append(trap_box("The OCP Trap",
    "Oral contraceptive pill (OCP) = SPECIFIC PROTECTION (Primary Prevention Level 2) — "
    "it specifically prevents pregnancy. NOT Primordial. NOT Health Promotion. "
    "This is a classic distractor because contraception feels like 'general health.'"))

story.append(vspace(6))
story.append(Paragraph("Lead Time & Screening Biases", H2))
story.append(Paragraph(
    "<b>Lead time</b> is the period between screen-detectable disease and clinically symptomatic disease. "
    "Screening advances the diagnosis by the lead time. If the patient's prognosis doesn't change, "
    "survival from diagnosis appears longer — but this is an ARTEFACT (Lead Time Bias).",
    BODY))
story.append(question_box(
    "5-year survival for lung cancer improves after low-dose CT screening is introduced, but annual mortality from lung cancer doesn't change. This is due to:",
    ["A. Selection bias", "B. Length bias", "C. Lead time bias", "D. Recall bias"],
    "C. Lead time bias",
    "The definitive clue: MORTALITY DID NOT CHANGE. "
    "Survival improved only because the diagnosis clock started EARLIER. "
    "Length bias would mean the screened tumours are inherently less lethal (slow-growing). "
    "Length bias clue: 'screened population has less aggressive tumours.'"
))
story.append(vspace(6))

story.append(Paragraph("Wilson & Jungner Screening Criteria (Classic 10)", H2))
story.append(Paragraph(
    "These criteria define when screening is worthwhile. "
    "The examiner asks which condition DOES NOT satisfy screening criteria.",
    BODY))
story.append(two_col_table([
    ["Important health problem", "High prevalence or serious condition"],
    ["Accepted treatment available", "Treatment must exist and be effective"],
    ["Facility for diagnosis/treatment", "Infrastructure must be available"],
    ["Latent or early symptomatic stage", "Screen BEFORE symptoms develop"],
    ["Suitable test available", "Sensitive, specific, acceptable to population"],
    ["Test acceptable to population", "Not overly painful/invasive"],
    ["Natural history understood", "Must know how it progresses"],
    ["Policy on whom to treat", "Clear criteria for follow-up/treatment"],
    ["Cost-effective", "Economic analysis must be favourable"],
    ["Continuing process", "Not a one-time event"],
], headers=["Wilson's Criterion", "Meaning"]))

story.append(vspace(4))
story.append(tip_box("Testicular Tumour — NOT Screened",
    "Testicular tumours do NOT have a recommended population-level screening programme. "
    "They present as painless swelling and are diagnosed clinically. "
    "Compare: Breast (mammography), Cervix (Pap/HPV), Prostate (PSA), Colorectal (FOBT). "
    "Exam trap: All four above have screening — testicular CA does not."))

story.append(vspace(6))
story.append(revision_capsule([
    "Primordial = prevent risk factors from emerging at population level",
    "Specific Protection (PP Level 2) = seatbelt, vaccine, OCP, iodised salt, Vitamin A prophylaxis",
    "Health Promotion (PP Level 1) = sanitary latrines, nutrition, health education",
    "Early Diagnosis & Treatment = screening tests (Pap smear, mammography)",
    "Disability Limitation = prevent worsening (callipers, dialysis, insulin in DM)",
    "Rehabilitation = restore function (prosthetics, physiotherapy, vocational rehab)",
    "Lead time bias = survival ↑ but mortality unchanged → clue: 'mortality not reduced'",
    "Length bias = screened cases less aggressive → clue: 'screen-detected cases do better anyway'",
    "Screening NOT recommended for testicular tumours",
    "PPV↑ when disease prevalence↑ | Sensitivity/specificity = fixed test properties",
]))
story.append(PageBreak())

# ============================================================================
# CHAPTER 4 — COMMUNICABLE DISEASE CONTROL
# ============================================================================
story.append(chapter_header(4, "Communicable Disease Control",
    "NTEP, NVBDCP, HIV, Malaria — High-Frequency Pattern Recognition"))

story.append(Paragraph("🎯 What the Examiner Targets", H2))
story.append(Paragraph(
    "The examiner does NOT expect encyclopaedic knowledge of every disease. "
    "They test SPECIFIC programme numbers, SPECIFIC surveillance indicators, and CLASSIFICATION rules. "
    "The three highest-yield disease domains are: TB (NTEP), Malaria (NVBDCP), and HIV.",
    BODY))

story.append(Paragraph("Malaria: Surveillance Indicators", H2))
story.append(two_col_table([
    ["<b>ABER</b> (Annual Blood Examination Rate)", "% of population with blood smear taken in a year. Target ≥ 10%. Measures OPERATIONAL EFFICIENCY of surveillance."],
    ["<b>API</b> (Annual Parasite Index)", "Confirmed malaria cases per 1000 population per year. Measures DISEASE BURDEN."],
    ["<b>SPR</b> (Slide Positivity Rate)", "% of examined slides that are positive. Measures TRANSMISSION INTENSITY."],
    ["<b>SFR</b> (Slide Falciparum Rate)", "% of positive slides that are P. falciparum. Measures SEVERITY risk."],
    ["<b>ABER ≠ epidemiological indicator</b>", "ABER is OPERATIONAL efficiency indicator, not epidemiological indicator."],
    ["IRS rounds (API > 2)", "2 rounds per year in high-transmission areas"],
    ["Microscope: 1 DMC covers", "25,000 population (NVBDCP norm)"],
    ["OptiMAL test", "Detects P. falciparum + P. vivax (pLDH-based RDT)"],
], headers=["Indicator", "Definition / Key Fact"],
col_widths=[(W-3.6*cm)*0.4, (W-3.6*cm)*0.6]))

story.append(vspace(6))
story.append(question_box(
    "Which malaria indicator measures the OPERATIONAL EFFICIENCY of the surveillance system?",
    ["A. Annual Parasite Index", "B. Annual Blood Examination Rate",
     "C. Slide Positivity Rate", "D. Slide Falciparum Rate"],
    "B. ABER (Annual Blood Examination Rate)",
    "ABER = what PROPORTION of population had their blood examined. "
    "It tells you HOW HARD the programme is working (operational efficiency). "
    "Trap: API sounds like an 'efficiency' metric but it actually measures DISEASE BURDEN (cases per 1000). "
    "Examiner frequently asks: 'ABER is NOT an epidemiological indicator' — TRUE, it's an operational indicator."
))
story.append(vspace(6))

story.append(Paragraph("NTEP (National Tuberculosis Elimination Programme)", H2))
story.append(two_col_table([
    ["MDR-TB definition", "Resistant to at least RIFAMPICIN + ISONIAZID (2 most potent 1st-line drugs)"],
    ["Pre-XDR-TB", "MDR-TB + resistant to ANY fluoroquinolone"],
    ["XDR-TB", "MDR-TB + fluoroquinolone + at least one Group A drug (bedaquiline/linezolid)"],
    ["GeneXpert (Xpert MTB/RIF)", "Detects MTB AND rifampicin resistance within 2 hours"],
    ["NIKSHAY", "TB notification + patient support platform"],
    ["DOTS incentive (DR-TB)", "₹500/month for DR-TB patients on treatment"],
    ["Community TB detection", "₹500 incentive for community referral leading to DR-TB detection"],
    ["Most peripheral RNTCP unit", "Designated Microscopy Centre (DMC), not PHC or sub-centre"],
    ["ESI extended sickness TB", "Up to 2 years (ESI Act)"],
], headers=["Fact", "Detail"],
col_widths=[(W-3.6*cm)*0.4, (W-3.6*cm)*0.6]))

story.append(vspace(4))
story.append(question_box(
    "MDR-TB is defined as resistance to:",
    ["A. Only rifampicin", "B. Rifampicin + Isoniazid", "C. All 4 first-line drugs", "D. Rifampicin + any injectable"],
    "B. Rifampicin + Isoniazid",
    "MDR = Multi-Drug Resistant = resistant to the TWO most important first-line drugs. "
    "If only rifampicin resistant = RR-TB (treated like MDR-TB). "
    "XDR adds fluoroquinolone resistance. Pre-XDR = MDR + fluoroquinolone. "
    "Trap: 'All 4 first-line drugs' is not a definition; XDR has a specific additional drug class."
))
story.append(vspace(6))

story.append(Paragraph("HIV: Surveillance, Diagnosis, Treatment", H2))
story.append(two_col_table([
    ["Sentinel surveillance purpose", "Monitor HIV prevalence trends in specific risk groups (NOT identify individuals)"],
    ["Diagnosis (asymptomatic adult)", "2 ELISA tests (different antigens). NOT require Western blot"],
    ["Opt-out HIV testing (pregnancy)", "Standard of care — tested unless patient specifically declines"],
    ["PEP initiation", "As soon as possible, ideally within 2 hours, definitely < 72 hours"],
    ["PEP regimen", "TDF + 3TC + DTG for 28 days"],
    ["PMTCT: highest risk factor for vertical transmission", "High maternal viral RNA load"],
    ["Elective C-section benefit", "Reduces vertical transmission by ~50% (before labour + membrane rupture)"],
    ["HIV + active TB", "Start ATT FIRST, then ART within 2 weeks (all CD4 counts)"],
    ["Exception (HIV + TB meningitis)", "Delay ART 4–8 weeks to reduce paradoxical IRIS"],
    ["IgA not transplacental", "Secretory IgA (OPV antibody) does NOT cross placenta"],
], headers=["Topic", "Key Fact"],
col_widths=[(W-3.6*cm)*0.42, (W-3.6*cm)*0.58]))

story.append(vspace(6))
story.append(question_box(
    "HIV + active TB patient (CD4=250). What to do?",
    ["A. Start ATT first, then ART within 2 weeks",
     "B. Start ART first, then ATT after 2 weeks",
     "C. Start both simultaneously",
     "D. Start ATT first, then ART after 8 weeks"],
    "A. ATT first → ART within 2 weeks",
    "WHO/NACO: Start ATT first (to reduce TB bacillary load), then add ART within 2 weeks "
    "for ALL CD4 counts. Earlier ART reduces mortality in severely immunocompromised. "
    "Exception: TB MENINGITIS → delay ART 4–8 weeks (paradoxical IRIS risk). "
    "Option D is wrong because '8 weeks' is only for meningitis, and that question specifies CD4=250 (no meningitis)."
))
story.append(vspace(6))

story.append(Paragraph("Vector Classification: Water Diseases", H2))
story.append(two_col_table([
    ["<b>Water-borne</b> (faeco-oral)", "Cholera, typhoid, hepatitis A, viral gastroenteritis"],
    ["<b>Water-washed</b> (poor hygiene)", "Scabies, trachoma, bacillary dysentery, louse typhus"],
    ["<b>Water-based</b> (aquatic invertebrate host)", "Schistosomiasis, dracunculiasis (guinea worm)"],
    ["<b>Water-related</b> (water-breeding vector)", "Malaria, filariasis, dengue, YELLOW FEVER, onchocerciasis"],
    ["<b>Water-dispersed</b>", "Legionella pneumophila (cooling towers/water systems)"],
], headers=["Category", "Disease Examples"],
col_widths=[(W-3.6*cm)*0.38, (W-3.6*cm)*0.62]))

story.append(vspace(4))
story.append(trap_box("Yellow Fever = Water-RELATED (not water-borne!)",
    "Examiner trap: Yellow fever is vector-borne (Aedes mosquito). "
    "Water is needed for Aedes breeding → 'water-related' category. "
    "Students confuse this with 'water-borne' (faeco-oral). "
    "Yellow fever is NOT transmitted by drinking water."))

story.append(vspace(6))
story.append(revision_capsule([
    "ABER = operational efficiency | API = disease burden per 1000 population",
    "MDR-TB = rifampicin + isoniazid resistance",
    "GeneXpert = detects MTB + rifampicin resistance in 2 hours",
    "HIV PEP = TDF+3TC+DTG for 28 days, start <72 hrs (ideally <2 hrs)",
    "HIV + TB → ATT first → ART within 2 weeks (EXCEPT TB meningitis: delay 4-8 wks)",
    "Highest vertical HIV risk = maternal viral RNA load",
    "Secretory IgA (OPV) does NOT cross placenta",
    "Yellow fever = water-RELATED (water-breeding vector), NOT water-borne",
    "Berkson's bias = hospital + 2 diseases → inflated association",
    "NVBDCP: 1 DMC covers 25,000 population",
]))
story.append(PageBreak())

# ============================================================================
# CHAPTER 5 — IMMUNIZATION & COLD CHAIN
# ============================================================================
story.append(chapter_header(5, "Immunization & Cold Chain",
    "Temperature Zones, VVM, Freeze-Sensitive Vaccines — Exam Favourites"))

story.append(Paragraph("🎯 What the Examiner Targets", H2))
story.append(Paragraph(
    "Cold chain questions test SPECIFIC TEMPERATURES for specific vaccines. "
    "The #1 tested fact: OPV requires freezing. "
    "The #2 tested fact: which vaccines are damaged by freezing (freeze-sensitive). "
    "The #3 tested fact: VVM (Vaccine Vial Monitor) interpretation.",
    BODY))

story.append(two_col_table([
    ["<b>OPV (Oral Polio Vaccine)</b>", "−15 to −25°C (frozen) at state/district level. −20°C most quoted. At PHC/sub-centre: 2–8°C for ≤1 month."],
    ["<b>Measles/MMR/Varicella</b>", "2–8°C (sensitive to heat AND light). Freeze OK but not needed."],
    ["<b>Freeze-sensitive vaccines</b>", "DPT, DT, TT, Hep B, Hep A, Rotavirus, IPV — damaged by freezing. Store 2–8°C."],
    ["<b>Shake test</b>", "Detect freeze-damage in freeze-sensitive vaccines"],
    ["<b>VVM Stage 1</b>", "Inner square LIGHTER than circle → SAFE to use"],
    ["<b>VVM Stage 2</b>", "Square same shade as circle → Use FIRST (still usable but prioritise)"],
    ["<b>VVM Stage 3</b>", "Square DARKER than circle → DO NOT USE"],
    ["<b>VVM Stage 4</b>", "Square much darker → DO NOT USE"],
], headers=["Vaccine / Test", "Key Temperature / Fact"],
col_widths=[(W-3.6*cm)*0.38, (W-3.6*cm)*0.62]))

story.append(vspace(6))
story.append(question_box(
    "Which vaccine is stored at the lowest temperature in the cold chain?",
    ["A. OPV", "B. DPT", "C. Hepatitis B", "D. Rotavirus"],
    "A. OPV (Oral Polio Vaccine)",
    "OPV must be FROZEN: −15 to −25°C at state/regional vaccine stores (−20°C most quoted). "
    "All others (DPT, Hep B, Rota, IPV) = 2–8°C. "
    "OPV is the MOST HEAT-SENSITIVE vaccine. Even at 2–8°C it has limited shelf life. "
    "Trap: Students think measles vaccine is stored frozen — it's not (2–8°C)."
))
story.append(vspace(4))
story.append(question_box(
    "Vaccine vial monitor (VVM) inner square is slightly DARKER than the surrounding circle. Action?",
    ["A. Use the vaccine", "B. Use vaccine but prioritise", "C. Discard immediately", "D. Shake test needed"],
    "C. DO NOT USE — discard",
    "VVM darker than circle = Stage 3 or 4 = cumulative heat damage threshold exceeded. DISCARD. "
    "Stage 2 (same shade) = 'use FIRST' (still safe but nearing expiry). "
    "Stage 1 (lighter) = safely use. "
    "Trap: 'use but prioritise' is the Stage 2 instruction, not Stage 3."
))
story.append(vspace(6))

story.append(Paragraph("Vaccine-Specific Key Facts", H2))
story.append(two_col_table([
    ["OPV: immunity conferred", "Both mucosal (IgA) AND humoral (IgG) — unlike IPV which gives humoral only"],
    ["Vaccine after disaster", "TETANUS (not cholera/typhoid — no mass vaccination evidence post-disaster)"],
    ["Varicella in seroneg. preg. HCW", "VZIG (Varicella-zoster Immunoglobulin) + avoid contact 10 days"],
    ["Minimum interval: 2 live vaccines", "4 weeks (28 days) if given on different days"],
    ["DTwP: false statement (classic PYQ)", "Prior reaction with temp >37°C is NOT a true contraindication (>40.5°C is)"],
    ["IgA not transplacental", "Secretory IgA (OPV) stays in mucosa / breast milk. IgG crosses placenta."],
    ["Mission Indradhanush (2014)", "Target: children partially/un-immunised. Now covers 12 VPDs."],
], headers=["Topic", "Key Fact"],
col_widths=[(W-3.6*cm)*0.42, (W-3.6*cm)*0.58]))

story.append(vspace(6))
story.append(memory_box("The Cold Chain Ladder — Memorise This Gradient",
    "−20°C → OPV only (frozen zone). "
    "2–8°C → ALL other vaccines. "
    "Room temperature → maximum 4 hours (open multidose vials, open day policy). "
    "Rule: If it must be frozen, it's OPV. If it's harmed by freezing, it's DPT/Hep B/Rota/IPV."))

story.append(vspace(6))
story.append(Paragraph("BMW Rules 2016: Colour-Code Recap", H2))
story.append(two_col_table([
    ["<b>Yellow bag/bin</b>", "Human anatomical waste, soiled dressings, blood bags, discarded blood products, cytotoxic/chemical liquid waste"],
    ["<b>Red bag</b>", "Contaminated plastic recyclables (IV sets, syringes without needles, gloves)"],
    ["<b>White/translucent puncture-proof container</b>", "Sharps (needles, blades, glass)"],
    ["<b>Blue bag/bin</b>", "Glass/metallic items, broken ampoules, uncontaminated glass"],
    ["<b>Black bag</b>", "General non-biomedical waste (paper, cardboard — NOT infectious)"],
    ["<b>Cytotoxic label</b>", "Yellow container with 'CYTOTOXIC' label for cytotoxic drugs"],
], headers=["Container", "Contents"],
col_widths=[(W-3.6*cm)*0.42, (W-3.6*cm)*0.58]))

story.append(vspace(4))
story.append(trap_box("Blood Bag Goes in YELLOW, Not Red",
    "Trap question: 'Blood bags are disposed in which colour container?' "
    "The correct answer is YELLOW (BMW 2016). "
    "Red = contaminated PLASTIC recyclables (no blood products). "
    "This is asked almost every year in some form."))

story.append(vspace(6))
story.append(revision_capsule([
    "OPV = −20°C (lowest temperature in cold chain)",
    "DPT, Hep B, Rota, IPV = freeze-sensitive (2–8°C, damaged by freezing)",
    "VVM: lighter than circle = use | same shade = use first | darker = DISCARD",
    "OPV confers mucosal IgA + humoral IgG (IPV only gives humoral IgG)",
    "Vaccine after disaster = Tetanus (NOT cholera/typhoid)",
    "2 live vaccines on different days → minimum 4-week interval",
    "BMW Yellow = anatomical waste + blood bags + cytotoxic drugs",
    "BMW Red = contaminated plastic recyclables",
    "BMW White/translucent = sharps",
    "Mission Indradhanush = launched 2014, covers 12 VPDs",
]))
story.append(PageBreak())

# ============================================================================
# CHAPTER 6 — NATIONAL HEALTH PROGRAMS
# ============================================================================
story.append(chapter_header(6, "National Health Programs",
    "JSY, JSSK, RBSK, PMMVY, Mission Indradhanush — Programme Recognition"))

story.append(Paragraph("🎯 What the Examiner Targets", H2))
story.append(Paragraph(
    "The examiner tests programme recognition: given a programme's description or features, "
    "identify the correct programme. The key is knowing the BENEFICIARY and KEY BENEFIT of each programme.",
    BODY))

story.append(two_col_table([
    ["<b>JSY</b> (Janani Suraksha Yojana)", "Cash incentive for institutional delivery. Rural: ₹1400 (high-focus states). Urban: ₹1000."],
    ["<b>JSSK</b> (Janani Shishu Suraksha Karyakram)", "FREE delivery, caesarean, drugs, diagnostics, blood, diet, referral transport for pregnant women + sick neonates."],
    ["<b>LaQshya</b>", "Labour room & maternity OT quality improvement. Targets respectful maternity care."],
    ["<b>Dakshata</b>", "Skilled birth attendant (SBA) training. Comprehensive Abortion Care (CAC) training."],
    ["<b>SUMAN</b> (Surakshit Matritva Aashwasan)", "Zero preventable maternal/newborn deaths. Free delivery, C-section, treatment guarantee."],
    ["<b>PMMVY</b> (Pradhan Mantri Matru Vandana Yojana)", "₹5000 maternity benefit for 1st LIVING child. Conditional cash transfer."],
    ["<b>NSSK</b> (Navjaat Shishu Suraksha Karyakram)", "Newborn resuscitation training at district/CHC level."],
    ["<b>RBSK</b> (Rashtriya Bal Swasthya Karyakram)", "Child health screening 0–18 years. 4Ds: Defects, Deficiencies, Diseases, Developmental delays."],
    ["<b>NBCC</b> (Newborn Care Corner)", "Equipment at every delivery point for immediate newborn care."],
    ["<b>Mission Indradhanush</b>", "Immunise partially/un-vaccinated children. 12 VPDs."],
], headers=["Programme", "Key Features"],
col_widths=[(W-3.6*cm)*0.32, (W-3.6*cm)*0.68]))

story.append(vspace(6))
story.append(Paragraph("Reproductive Health Programme (RCH) Structure", H2))
story.append(two_col_table([
    ["RCH programme implementation level", "DISTRICT (differential district approach based on CBR + female literacy)"],
    ["Sub-centre: coverage", "5,000 population (plain) | 3,000 (tribal/hilly)"],
    ["Sub-centre: staff", "1 ANM + 1 Male Multipurpose Worker"],
    ["Sub-centre: most peripheral?", "YES — first contact point between PHC system and community"],
    ["PHC: covers", "30,000 population (plain) | 20,000 (tribal)"],
    ["CHC: covers", "1,20,000 population (30-bedded)"],
    ["NUHM: 1 UPHC per", "50,000 slum population"],
], headers=["Topic", "Key Fact"]))

story.append(vspace(4))
story.append(question_box(
    "The Reproductive and Child Health (RCH) programme activities are targeted at which level?",
    ["A. Sub-centre", "B. Anganwadi", "C. District", "D. Taluka"],
    "C. District",
    "RCH uses a DIFFERENTIAL approach: all districts categorised A/B/C by crude birth rate and female literacy. "
    "Weaker districts get more support. District = planning, resource allocation, and monitoring unit. "
    "Trap: Students say 'Sub-centre' because sub-centre delivers maternal/child health services "
    "on the ground — but the PROGRAMME is TARGETED at the district level."
))
story.append(vspace(6))

story.append(Paragraph("ICDS (Integrated Child Development Services)", H2))
story.append(two_col_table([
    ["Beneficiaries", "Children 0–6 years + pregnant/lactating women"],
    ["Implemented through", "Anganwadi Centres"],
    ["Services", "Supplementary nutrition, immunisation, health check-up, referral, health education, pre-school education"],
    ["Nutrition supplement age", "6 months to 6 years (complementary feeding)"],
    ["Complementary feeding start", "6 months (WHO recommends 180 days)"],
    ["WIFS (Weekly Iron Folic Supplementation)", "60 mg elemental Fe + 500 µg folic acid WEEKLY for adolescents (10–19 years)"],
], headers=["Aspect", "Detail"]))

story.append(vspace(6))
story.append(Paragraph("IUD: Contraindications", H2))
story.append(two_col_table([
    ["ABSOLUTE contraindications", "Pregnancy, active/recent PID, undiagnosed vaginal bleeding, cervical/uterine malignancy, previous ectopic pregnancy"],
    ["RELATIVE contraindications", "Uterine malformation (distorted cavity), anaemia, menorrhagia, history of PID"],
    ["NOT an absolute contraindication", "Uterine malformation (only relative)"],
], headers=["Category", "Examples"],
col_widths=[(W-3.6*cm)*0.35, (W-3.6*cm)*0.65]))

story.append(vspace(6))
story.append(revision_capsule([
    "JSY = institutional delivery cash incentive | JSSK = free delivery + c-section + transport",
    "PMMVY = ₹5000 for 1st living child (conditional cash transfer)",
    "RBSK = 4D screening (0–18 yrs): Defects, Deficiencies, Diseases, Developmental delays",
    "RCH programme = targeted at DISTRICT level",
    "Sub-centre = most peripheral health facility (5,000/plain, 3,000/tribal)",
    "NUHM: 1 UPHC per 50,000 slum population",
    "WIFS = 60 mg Fe + 500 µg FA weekly for 10–19 year olds",
    "ICDS beneficiaries = 0–6 years + pregnant/lactating women (not 0–18 years)",
    "IUD absolute contraindication: NOT uterine malformation (it's only relative)",
    "Complementary feeding starts at 6 months (180 days)",
]))
story.append(PageBreak())

# ============================================================================
# CHAPTER 7 — ENVIRONMENTAL & OCCUPATIONAL HEALTH
# ============================================================================
story.append(chapter_header(7, "Environmental & Occupational Health",
    "Water, Air, Waste, Factories Act — Numbers the Examiner Loves"))

story.append(Paragraph("🎯 What the Examiner Targets", H2))
story.append(Paragraph(
    "Environmental health is tested through specific NUMBERS and CLASSIFICATIONS. "
    "The examiner gives you a scenario and expects you to recall the right law, "
    "the right concentration, or the right colour-coded bag.",
    BODY))

story.append(Paragraph("Water Quality & Purification", H2))
story.append(two_col_table([
    ["Bleaching powder active agent", "Hypochlorous acid (HOCl) — 70-80× more effective than hypochlorite ion"],
    ["Bleaching powder available chlorine", "33% available chlorine"],
    ["Nalgonda technique", "Alum + Lime (defluoridation of drinking water)"],
    ["Fecal contamination indicator in water", "E. coli (most reliable indicator)"],
    ["Hardness NOT caused by", "NaCl (sodium chloride) — hardness caused by Ca²⁺, Mg²⁺ salts"],
    ["Water sample during cholera outbreak", "Collect BEFORE chlorination (to detect Vibrio, not kill it first)"],
    ["Fluorosis treatment", "Defluoridation (Nalgonda technique) — NOT fluoride supplementation"],
], headers=["Topic", "Key Fact"]))

story.append(vspace(4))
story.append(question_box(
    "The active disinfectant property of bleaching powder is due to:",
    ["A. Hypochlorite ion", "B. Chloride ion", "C. Hypochlorous acid", "D. Calcium oxide"],
    "C. Hypochlorous acid (HOCl)",
    "Bleaching powder (CaOCl₂) releases HOCl on contact with water. "
    "HOCl is a weak acid but 70-80x more active as a disinfectant than OCl⁻. "
    "Trap: Students say 'hypochlorite ion' because chlorine/bleach sounds like hypochlorite. "
    "The KEY: it's HYPO-CHLOR-OUS ACID (HOCl), not the hypochlorite ION (OCl⁻)."
))
story.append(vspace(6))

story.append(Paragraph("Air Quality Index (AQI)", H2))
story.append(two_col_table([
    ["AQI 0–50", "Good (green)"],
    ["AQI 51–100", "Satisfactory (light green)"],
    ["AQI 101–200", "Moderate (yellow)"],
    ["AQI 201–300", "Poor (orange)"],
    ["AQI 301–400", "Very poor (red)"],
    ["AQI 401–500", "Severe (maroon)"],
    ["AQI = 407 category", "Severe (>400)"],
    ["Routine monitoring indicators", "SO₂ + smoke/PM + Lead (Pb) — Park's classic triad"],
    ["AQI components (comprehensive)", "PM2.5, PM10, NO₂, SO₂, CO, O₃, NH₃, Pb"],
], headers=["AQI / Topic", "Value / Detail"]))

story.append(vspace(4))
story.append(question_box(
    "AQI of 394–407 is classified as:",
    ["A. Very poor", "B. Hazardous", "C. Poor", "D. Severe"],
    "D. Severe",
    "AQI 401–500 = Severe (maroon). The range 394–407 spans Very Poor/Severe. "
    "394 = Very Poor; 401+ = Severe. This is a near-boundary question designed to trap. "
    "The examiner expects you to know that 401+ = Severe. "
    "Note: Some USA scales have 'Hazardous' (>300) but Indian scale uses 'Severe' for 401–500."
))
story.append(vspace(6))

story.append(Paragraph("Occupational Health: Factories Act 1948", H2))
story.append(two_col_table([
    ["Normal working hours", "48 hours/week (9 hours/day)"],
    ["Maximum with overtime", "60 hours/week (2 hours overtime/day)"],
    ["Overtime wages", "Double the normal rate"],
    ["Adolescents (15–18 years)", "Maximum 4.5 hours/day, only 6 AM–7 PM"],
    ["ESI Act: extended sickness TB", "Up to 2 years (extended sickness benefit)"],
    ["ESI Act: normal sickness benefit", "91 days/year"],
    ["PPE: NOT included", "Lab coat, radiation badge (monitoring, not protecting)"],
], headers=["Provision", "Detail"]))

story.append(vspace(4))
story.append(question_box(
    "Maximum work hours per week including overtime under the Factories Act 1948?",
    ["A. 48 hours", "B. 50 hours", "C. 60 hours", "D. 72 hours"],
    "C. 60 hours",
    "Normal: 48 h/week. Overtime allowed: up to 2 extra hours/day = maximum 60 h/week. "
    "This appears repeatedly in PYQs (2018, 2019, 2020). "
    "Trap: '48 hours' is the NORMAL limit; 60 is the MAXIMUM including overtime. "
    "The question specifically says 'including overtime' → 60."
))
story.append(vspace(6))

story.append(Paragraph("Pneumoconiosis: Dust-Disease Matching", H2))
story.append(two_col_table([
    ["Silicosis", "Silica / quartz dust — mining, quarrying, stone cutting"],
    ["Asbestosis", "Asbestos — shipbuilding, insulation, roofing, brake lining"],
    ["Byssinosis", "Cotton dust — textile mills (Monday fever)"],
    ["Coal worker's pneumoconiosis", "Coal dust — coal mining"],
    ["Siderosis", "Iron dust — iron mining/processing (benign)"],
    ["Anthracosis", "Carbon/coal dust — air pollution (common urban finding)"],
    ["Bagassosis", "Sugarcane bagasse — sugar industry"],
    ["Farmer's lung", "Mouldy hay (thermophilic actinomycetes) — hypersensitivity pneumonitis"],
], headers=["Disease", "Causative Dust / Occupation"]))

story.append(vspace(6))
story.append(revision_capsule([
    "Bleaching powder active agent = Hypochlorous acid (HOCl)",
    "Nalgonda technique = Alum + Lime (defluoridation)",
    "Factories Act: normal 48 h/wk; max with OT = 60 h/wk",
    "ESI extended sickness TB = up to 2 years",
    "AQI 401–500 = Severe | 301–400 = Very Poor | 201–300 = Poor",
    "BMW Yellow = anatomical waste + chemical liquid waste (cytotoxic + body secretions)",
    "BMW Red = contaminated plastic recyclables",
    "BMW White = sharps",
    "Lab coat = NOT a PPE",
    "Byssinosis = cotton dust (textile workers)",
]))
story.append(PageBreak())

# ============================================================================
# CHAPTER 8 — HEALTH ADMINISTRATION & INFRASTRUCTURE
# ============================================================================
story.append(chapter_header(8, "Health Administration & Infrastructure",
    "Norms, Population Coverage, Administration Levels — Rapid Recall Zone"))

story.append(Paragraph("🎯 What the Examiner Targets", H2))
story.append(Paragraph(
    "This chapter is about POPULATION NORMS. The examiner gives a population size "
    "and asks what infrastructure serves it, or gives a facility and asks what population it covers.",
    BODY))

story.append(two_col_table([
    ["Sub-centre (plain)", "5,000 population | 1 ANM + 1 Male MPW"],
    ["Sub-centre (tribal/hilly)", "3,000 population"],
    ["PHC (plain)", "30,000 population | 1 Medical Officer"],
    ["PHC (tribal)", "20,000 population"],
    ["CHC", "1,20,000 population | 30 beds, 4 specialists"],
    ["District hospital", "1–3 million (district-level)"],
    ["UPHC (Urban, NUHM)", "50,000 slum population"],
    ["Vision 2020 Primary Vision Centre", "50,000 population | 1 ophthalmic assistant"],
    ["Vision 2020 Secondary Service Centre", "5 lakh (500,000) population | 2 ophthalmologists"],
    ["Vision 2020 Training Centre", "50 lakh (5 million) population"],
    ["Vision 2020 Centre of Excellence", "5 crore (50 million) population"],
], headers=["Facility", "Population Coverage / Staff"],
col_widths=[(W-3.6*cm)*0.42, (W-3.6*cm)*0.58]))

story.append(vspace(6))
story.append(question_box(
    "Under Vision 2020 - Right to Sight, a secondary service centre covers which population?",
    ["A. 10,000", "B. 50,000", "C. 1 lakh", "D. 5 lakh"],
    "D. 5 lakh (500,000)",
    "Vision 2020 pyramid (remember 50k → 5L → 50L → 5Cr):\n"
    "Primary Vision Centre = 50,000 | Secondary Service Centre = 5 LAKH | "
    "Training Centre = 50 lakh | Centre of Excellence = 5 crore. "
    "Trap: Students confuse Primary Vision Centre (50k) with Secondary Service Centre (5L). "
    "The '5' in 5 lakh matches 'Secondary' = both have an 'S' and 5."
))
story.append(vspace(6))

story.append(Paragraph("Health Administration Concepts", H2))
story.append(two_col_table([
    ["Principal administrative unit in India", "DISTRICT (headed by District Collector, IAS)"],
    ["Management by Objective (MBO)", "Behavioural science method — goal-setting with employee participation"],
    ["Cost-benefit analysis", "Both costs AND benefits measured in MONETARY terms"],
    ["Cost-effectiveness analysis", "Costs in money; benefits in NATURAL UNITS (DALYs, life-years saved)"],
    ["Efficiency", "Output/Input ratio (how much output for given input)"],
    ["Effectiveness", "Degree to which objectives are achieved (outcome vs goal)"],
    ["QALY (Quality-Adjusted Life Year)", "Combines quantity + quality of life. 1 QALY = 1 year in perfect health."],
    ["DALY (Disability-Adjusted Life Year)", "YLL (years life lost) + YLD (years lived with disability)"],
    ["Delphi technique", "Structured expert consensus method — repeated anonymous surveys"],
    ["Clinical management in health programme", "Classified under PROCESS (not input or outcome)"],
], headers=["Concept", "Key Fact"]))

story.append(vspace(4))
story.append(Paragraph("ASHA Role", H2))
story.append(two_col_table([
    ["ASHA full form", "Accredited Social Health Activist"],
    ["Coverage", "1 per 1000 population (rural village)"],
    ["Role", "Community link worker, mobilisation, facilitates access to health services"],
    ["Incentives", "Performance-based (not fixed salary) — e.g., for institutional deliveries referred"],
    ["Gray kit", "Contains treatment for STIs (syndromic management) — given to ASHA"],
], headers=["Aspect", "Detail"]))

story.append(vspace(6))
story.append(Paragraph("MHA 2017 — Mental Healthcare Act", H2))
story.append(two_col_table([
    ["Voluntary admission max duration", "90 days (Section 90)"],
    ["If admission > 30 days / readmission within 7 days", "Two psychiatrists must review + inform MHRB"],
    ["Consent review", "Fortnightly"],
    ["Advanced Directive (AD)", "Patient can specify desired/unwanted treatment in advance"],
], headers=["Provision", "Detail"]))

story.append(vspace(6))
story.append(revision_capsule([
    "Sub-centre: 5,000/plain, 3,000/tribal — most peripheral health facility",
    "PHC: 30,000/plain — 1 Medical Officer",
    "CHC: 1,20,000 — 30 beds, 4 specialists (FRU = First Referral Unit)",
    "UPHC (NUHM): 50,000 slum population",
    "Vision 2020: PVC=50k | Secondary=5 lakh | Training=50L | CoE=5 crore",
    "DALY = YLL + YLD",
    "QALY = 1 year in perfect health",
    "Cost-benefit analysis = both in money | Cost-effectiveness = costs in money + natural units",
    "MHA 2017 voluntary admission maximum = 90 days",
    "ASHA = 1 per 1000 population, performance-based incentives",
]))
story.append(PageBreak())

# ============================================================================
# CHAPTER 9 — NUTRITION, DEMOGRAPHY & VITAL STATISTICS
# ============================================================================
story.append(chapter_header(9, "Nutrition, Demography & Vital Statistics",
    "Deficiency Diseases, Vital Rates, Demographic Transition"))

story.append(Paragraph("🎯 What the Examiner Targets", H2))
story.append(Paragraph(
    "Nutrition questions test deficiency disease recognition and Vitamin A dosing. "
    "Demography questions test which RATE measures what, and what India's "
    "demographic stage implies.",
    BODY))

story.append(Paragraph("Nutritional Deficiency Diseases", H2))
story.append(two_col_table([
    ["Vitamin A deficiency signs (hierarchy)", "Night blindness → Bitot's spots → Xerophthalmia → Keratomalacia"],
    ["Vitamin A: 2-year-old with keratomalacia", "2,00,000 IU on Day 1, Day 2, Day 14 (3 doses)"],
    ["Vitamin A prophylaxis (6m–5yr)", "2,00,000 IU every 6 months"],
    ["Phrynoderma", "Essential Fatty Acid (EFA) deficiency — 'toad skin' (follicular hyperkeratosis)"],
    ["Neurolathyrism", "Lathyrus sativus (khesari dal) → BOAA toxin → spastic paraparesis"],
    ["Fluorosis (dental/skeletal)", "Excess fluoride — treated by NALGONDA defluoridation, NOT supplementation"],
    ["Iodine RDA (lactating women)", "250 µg/day (NIN 2020)"],
    ["Dietary cholesterol limit (CAD prevention)", "< 200 mg/1000 kcal"],
    ["Gomez Grade I (mild malnutrition)", "76–90% weight-for-age"],
    ["Gomez Grade II (moderate)", "61–75% weight-for-age"],
    ["Gomez Grade III (severe)", "< 60% weight-for-age"],
], headers=["Topic", "Key Fact"],
col_widths=[(W-3.6*cm)*0.42, (W-3.6*cm)*0.58]))

story.append(vspace(6))
story.append(question_box(
    "A child has phrynoderma (rough scaly 'toad skin'). Primarily caused by deficiency of:",
    ["A. Vitamin A", "B. Essential fatty acids", "C. Vitamin D", "D. Vitamin E"],
    "B. Essential fatty acids",
    "Phrynoderma (follicular hyperkeratosis) is primarily caused by EFA (linoleic acid) deficiency. "
    "Students automatically think 'Vitamin A' because Vitamin A causes skin changes (xerosis). "
    "Trap: Vitamin A deficiency → xerosis, night blindness, Bitot's spots, keratomalacia — "
    "but the specific term PHRYNODERMA points to EFA."
))
story.append(vspace(6))

story.append(Paragraph("Vital Statistics — Knowing Which Rate Measures What", H2))
story.append(two_col_table([
    ["<b>Crude Birth Rate (CBR)</b>", "Live births/1000 mid-year population/year. CRUDE = includes non-fertile denominator."],
    ["<b>TFR</b> (Total Fertility Rate)", "Average children a woman would have in her lifetime. Best measure of fertility trends."],
    ["<b>ASFR</b> (Age-Specific Fertility Rate)", "Births to women of a specific age group per 1000 women in that age"],
    ["<b>IMR</b>", "Infant deaths (<1 year) per 1000 live births. Best single indicator of community health."],
    ["<b>MMR</b>", "Maternal deaths per 1,00,000 live births. SDG target: <70 by 2030."],
    ["<b>NMR</b>", "Neonatal deaths (<28 days) per 1000 live births"],
    ["<b>CBR disadvantage</b>", "Denominator includes males + post-menopausal women → CRUDE, not fertility-specific"],
    ["<b>Demographic transition (India)</b>", "Late expanding/Stage 3 (declining fertility, declining mortality)"],
    ["<b>CPR = 2.1</b>", "Net Reproduction Rate = 1 (replacement fertility level)"],
], headers=["Rate", "Definition / Key Fact"],
col_widths=[(W-3.6*cm)*0.38, (W-3.6*cm)*0.62]))

story.append(vspace(4))
story.append(question_box(
    "CBR is a 'crude' measure because:",
    ["A. It uses a small sample", "B. Denominator includes non-fertile individuals",
     "C. It is calculated annually", "D. It underestimates actual births"],
    "B. Denominator includes non-fertile individuals",
    "CBR = live births / total mid-year population × 1000. "
    "The denominator includes males, elderly, and children — NOT all are at risk of childbirth. "
    "Therefore CBR is CRUDE (approximate). For ACTUAL fertility measurement → TFR or ASFR. "
    "TFR is the single best indicator of fertility trends."
))
story.append(vspace(6))

story.append(Paragraph("Health Indicators: PQLI, HDI, GHI", H2))
story.append(two_col_table([
    ["<b>PQLI</b> (Physical Quality of Life Index)", "3 components: Life expectancy at age 1 + IMR + Basic literacy rate"],
    ["<b>HDI</b> (Human Development Index)", "3 components: Life expectancy (min 20, max 85 yrs) + Education + GNI per capita"],
    ["<b>GHI</b> (Global Hunger Index)", "4 components: Undernourishment + Child stunting + Child wasting + U5MR (NOT IMR)"],
    ["GHI: what is NOT included", "IMR is NOT a GHI component (U5MR is used instead)"],
    ["DALY", "YLL + YLD (burden of disease measure)"],
    ["YPLL", "Years of Potential Life Lost = age at death − 65. Measures premature deaths."],
], headers=["Indicator", "Components / Key Fact"],
col_widths=[(W-3.6*cm)*0.38, (W-3.6*cm)*0.62]))

story.append(vspace(4))
story.append(memory_box("PQLI vs HDI vs GHI — Never Confuse Them",
    "PQLI = 3 components, Morris (1979). Remember 'P for PQLI, P for Physical (child) indicators': "
    "Life expectancy at age 1, IMR, Literacy. "
    "HDI = 3 components, UNDP. Health + Education + Income. "
    "GHI = 4 components, IFPRI. The trap: GHI uses U5MR (under-5 mortality), NOT IMR."))

story.append(vspace(6))
story.append(revision_capsule([
    "Vitamin A for keratomalacia: 2,00,000 IU × 3 doses (Day 1, 2, 14)",
    "Phrynoderma = EFA deficiency (not Vitamin A)",
    "Gomez: Grade I=76-90% | Grade II=61-75% | Grade III=<60%",
    "CBR = crude (denominator includes non-fertile) | TFR = best fertility measure",
    "IMR = best single indicator of community health",
    "MMR: SDG target <70 per 1,00,000 live births by 2030",
    "PQLI: life expectancy at 1 yr + IMR + literacy",
    "GHI: undernourishment + child stunting + child wasting + U5MR (NOT IMR)",
    "HDI: life expectancy (min 20, max 85 yr) + education + GNI per capita",
    "CPR = 2.1 → NRR = 1 (replacement level fertility)",
]))
story.append(PageBreak())

# ============================================================================
# CHAPTER 10 — HEALTH INDICATORS & INTERNATIONAL HEALTH
# ============================================================================
story.append(chapter_header(10, "Health Indicators & International Health",
    "SDGs, WHO Structure, Vision 2020, Historical Milestones"))

story.append(Paragraph("🎯 What the Examiner Targets", H2))
story.append(Paragraph(
    "International health questions test WHO structure, SDG targets, Vision 2020 norms, "
    "and historical milestones. These are high-yield FACTUAL questions — the answer is usually a "
    "very specific number or name.",
    BODY))

story.append(two_col_table([
    ["SDG 3.1: MMR target by 2030", "< 70 per 1,00,000 live births (no country > 140)"],
    ["SDG 3: Ensure healthy lives", "Health-specific SDG. All other health targets under SDG 3."],
    ["WHO HQ", "Geneva, Switzerland"],
    ["WHO Regional Office Europe (EURO)", "Copenhagen, Denmark"],
    ["WHO Regional Office SEARO", "New Delhi, India (covers India)"],
    ["WHO Regional Office PAHO", "Washington DC (Americas)"],
    ["WHO Regional Office EMRO", "Cairo (Eastern Mediterranean)"],
    ["WHO Regional Office AFRO", "Brazzaville, Congo"],
    ["WHO Regional Office WPRO", "Manila, Philippines"],
    ["MONICA project", "Multinational MOnitoring of trends and determinants In CArdiovascular disease (WHO, 26 countries)"],
    ["Colombo Plan", "Technical/economic cooperation in South and Southeast Asia"],
    ["First Public Health Act", "1848, England — by Edwin Chadwick"],
    ["Miasma theory", "Disease from 'bad air' / rotting matter — pre-germ theory era"],
], headers=["Topic", "Key Fact"],
col_widths=[(W-3.6*cm)*0.42, (W-3.6*cm)*0.58]))

story.append(vspace(6))
story.append(Paragraph("Disease Eradication Terminology", H2))
story.append(two_col_table([
    ["<b>Control</b>", "Reduction to acceptable levels. Disease still present."],
    ["<b>Elimination</b>", "Regional/national interruption of transmission. Causative agent may persist."],
    ["<b>Eradication</b>", "Worldwide reduction to ZERO cases. Agent may still exist (e.g., variola in labs)."],
    ["<b>Extinction</b>", "Agent completely destroyed worldwide. No longer exists anywhere."],
    ["Eradicated diseases", "Smallpox (1980). Rinderpest (2011, animal disease)."],
    ["Eliminated in India", "Polio (2014), Guinea worm, Yaws, Neonatal tetanus"],
], headers=["Term", "Definition / Example"],
col_widths=[(W-3.6*cm)*0.32, (W-3.6*cm)*0.68]))

story.append(vspace(4))
story.append(question_box(
    "Causative agent is present but disease transmission is interrupted in a region. This is:",
    ["A. Eradication", "B. Elimination", "C. Control", "D. Extinction"],
    "B. Elimination",
    "Elimination = REGIONAL interruption of transmission, even if the organism still exists. "
    "Example: India achieved polio ELIMINATION (2014) — poliovirus still exists globally. "
    "Eradication = WORLDWIDE zero cases (smallpox, 1980). "
    "Extinction = the agent is destroyed everywhere (no natural reservoirs, no lab stocks). "
    "Control = reduced but not eliminated."
))
story.append(vspace(6))

story.append(Paragraph("Indian Constitution: Health-Related Articles", H2))
story.append(two_col_table([
    ["Article 21", "Right to Life — interpreted to include right to health"],
    ["Article 47", "Duty of State to raise nutrition/health standard"],
    ["Concurrent List", "Both Central AND State can legislate — includes ADULTERATION of food"],
    ["State List", "State-only legislation — includes PUBLIC HEALTH and sanitation"],
    ["Union List", "Central-only — includes ports, quarantine, regulation of medical profession"],
], headers=["Article / List", "Health relevance"]))

story.append(vspace(6))
story.append(Paragraph("Disaster Management", H2))
story.append(two_col_table([
    ["Disaster management cycle sequence", "Mitigation → Preparedness → Response → Recovery"],
    ["Vaccine priority post-disaster", "Tetanus (injury + contamination risk). NOT cholera/typhoid."],
    ["Toxic fumes (industrial disaster)", "Seal windows/doors, stay indoors (shelter-in-place). Do NOT run outside."],
    ["PHC disaster preparation", "Stockpile drugs, identify manpower, clear communication lines"],
], headers=["Topic", "Key Fact"]))

story.append(vspace(6))
story.append(Paragraph("Surveillance & Monitoring — Final Clarification", H2))
story.append(two_col_table([
    ["Surveillance", "Continuous systematic collection, analysis, interpretation and dissemination for public health action (includes outbreak detection)"],
    ["Monitoring", "Routine continuous measurement of PROGRAMME INPUTS and OUTPUTS (process measurement)"],
    ["Evaluation", "Measures whether OBJECTIVES have been achieved (outcomes vs goals). Periodic, not continuous."],
    ["Sentinel surveillance purpose", "Monitor TRENDS in high-risk or hard-to-reach populations at selected sites"],
    ["De facto census", "Counted at place of ENUMERATION (wherever found on census date)"],
    ["De jure census", "Counted at place of USUAL RESIDENCE (not where found)"],
], headers=["Concept", "Definition"],
col_widths=[(W-3.6*cm)*0.32, (W-3.6*cm)*0.68]))

story.append(vspace(6))
story.append(revision_capsule([
    "SDG 3.1: MMR < 70/1,00,000 live births by 2030",
    "WHO SEARO = New Delhi | EURO = Copenhagen | HQ = Geneva",
    "MONICA = cardiovascular disease trends monitoring (WHO, 26 countries)",
    "Eradication = worldwide zero | Elimination = regional interruption | Extinction = agent destroyed",
    "Smallpox = only human disease eradicated (1980)",
    "India polio elimination = 2014",
    "Concurrent List includes food adulteration | State List includes public health",
    "Disaster cycle: Mitigation → Preparedness → Response → Recovery",
    "Monitoring = programme process (inputs/outputs) | Evaluation = outcomes vs goals",
    "Sentinel surveillance = high-risk/hard-to-reach populations at selected sites",
]))
story.append(PageBreak())

# ── FINAL WORD ───────────────────────────────────────────────────────────────
story.append(vspace(20))
story.append(colored_box([
    Paragraph("You Have Reached the End — Now the Real Work Begins", S(
        "fw1", fontSize=14, textColor=C_TEAL, fontName="Helvetica-Bold",
        alignment=TA_CENTER, leading=18)),
    vspace(4),
    Paragraph(
        "PSM is not about memorising 260 facts. It is about recognising 15 patterns "
        "that the examiner uses to construct those questions. "
        "You have now seen all 15. The next step is ACTIVE RECALL — "
        "close the book, take a blank paper, and try to reconstruct each chapter's "
        "revision capsule from memory. Every item you miss is a revision priority.",
        S("fw2", fontSize=10, textColor=C_DARK, fontName="Helvetica",
          alignment=TA_JUSTIFY, leading=15)),
    vspace(4),
    Paragraph("Good luck. The exam is yours to own.", S(
        "fw3", fontSize=11, textColor=C_TEAL, fontName="Helvetica-Bold",
        alignment=TA_CENTER, leading=14)),
], bg=HexColor("#eef4fb"), border=C_TEAL, padding=14))

story.append(vspace(12))
story.append(Paragraph(
    "Based on 260+ NEET-PG PYQs (2015–2025) from the Neet-Pg2026 Question Bank Repository.",
    FOOTER))
story.append(Paragraph(
    "For errors or updates, contribute to: github.com/skm9097/neet-pg2026",
    FOOTER))

# ── BUILD PDF ─────────────────────────────────────────────────────────────────
doc.build(story, onFirstPage=on_page, onLaterPages=on_page)
print(f"PDF generated: {OUTPUT}")
