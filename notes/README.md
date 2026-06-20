# High-Yield Concept Notes

**Question-Engraved Concept Books** for NEET PG · INICET · FMGE · UPSC CMS

Each notebook is built directly from the corresponding PYQ database in
`../question-bank/subject-wise/` — every concept is taught through the questions
themselves rather than as abstract theory.

## Files

| File | Subject | Pages | Source PYQs |
|------|---------|-------|-------------|
| [`OBG_Concept_Book.pdf`](OBG_Concept_Book.pdf) | Obstetrics & Gynaecology | 212 | 1,063 |
| [`OBG_Concept_Book.md`](OBG_Concept_Book.md) | Obstetrics & Gynaecology (Markdown source) | — | — |
| [`PSM_High_Yield_Notes.pdf`](PSM_High_Yield_Notes.pdf) | Community Medicine / PSM | 38 | 260+ |
| `generate_obg_pdf.py` | OBG PDF generator (markdown + weasyprint) | — | — |
| `generate_psm_notes.py` | PSM PDF generator (reportlab) | — | — |

## Regenerating the PDFs

### OBG (from Markdown via WeasyPrint)
```bash
cd notes/
pip install markdown pymdown-extensions weasyprint pypdf
python3 generate_obg_pdf.py
```
The OBG generator reads `OBG_Concept_Book.md` (65,739 words), converts via
the `markdown` library, and renders to PDF with custom CSS for styling
question/answer blocks, tables, comparison boxes, and chapter bands.

### PSM (programmatically constructed)
```bash
cd notes/
pip install reportlab
python3 generate_psm_notes.py
```

## OBG Concept Book — Chapter Map

**Part I — Obstetrics**
1. Normal Pregnancy — Anatomy, Physiology & Embryology
2. Antenatal Care — Screening, Surveillance & Fetal Monitoring
3. Hypertensive Disorders & Medical Complications in Pregnancy
4. Labour, Delivery & Obstetric Emergencies

**Part II — Gynaecology**
5. Contraception & Family Planning
6. Infertility & Assisted Reproduction
7. AUB, Menstrual Disorders & Endocrine Gynaecology
8. Menopause, HRT & Pelvic Floor Disorders
9. Benign Gynaecological Conditions
10. Gynaecological Infections & Developmental Anomalies
11. Cervical & Endometrial Cancer
12. Ovarian Cancer & Gestational Trophoblastic Disease

## PSM Concept Book — Chapter Map

1. Biostatistics — Tests, normal distribution, screening calculations, bias types
2. Epidemiology & Study Designs — Cohort/case-control/ecological, confounding, OR vs RR
3. Screening & Levels of Prevention — Leavell & Clark, lead time bias, Wilson criteria
4. Communicable Disease Control — NTEP/MDR-TB, NVBDCP/malaria, HIV PEP/PMTCT
5. Immunization & Cold Chain — Temperature norms, VVM stages, BMW colour coding
6. National Health Programs — JSY, JSSK, RBSK, RCH, PMMVY, Mission Indradhanush
7. Environmental & Occupational Health — Water, AQI, Factories Act, pneumoconioses
8. Health Administration — PHC/CHC norms, Vision 2020, ASHA, QALY/DALY
9. Nutrition, Demography & Vital Statistics — Vitamin A, deficiency diseases, vital rates
10. Health Indicators & International Health — PQLI/HDI/GHI, SDGs, WHO regions

## Methodology

Each chapter follows the same pattern:

1. **🎯 Big Picture** — examiner psychology, what gets tested and why
2. **📊 Question Pattern Map** — recurring PYQ themes, traps, framing styles
3. **📚 Core Concept Deep Dive** — theory taught through embedded MCQs with full trap analysis and wrong-option explanations
4. **⚠️ Bias Removal** — psychological traps students fall into
5. **🔄 Variations & Twists** — modified/reverse question training
6. **🧠 Memory Engineering** — elegant mnemonics, contrast-based anchors
7. **⚡ Ultra High-Yield Revision Layer** — 20-second summaries, volatile facts, comparison tables for last-minute revision
