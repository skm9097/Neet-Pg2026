# NEET-PG Question Bank

Recall-based NEET-PG questions reformatted as study notes, organised by year. See [`ATTRIBUTION.md`](ATTRIBUTION.md) for source and usage notice.

## Folder Structure

```
question-bank/
├── ATTRIBUTION.md          Source attribution & use notice
├── STUDY-PLAN.md           Suggested study schedule + how to use this repo
├── template.md             Schema for adding new questions
├── subject-wise/           Multi-year pools across all 19 subjects (7,455 Qs)
│   ├── README.md                           (index + counts)
│   ├── anaesthesia.md       (80 Qs)
│   ├── anatomy.md           (828 Qs)
│   ├── biochemistry.md      (462 Qs)
│   ├── community-medicine.md (744 Qs)
│   ├── dermatology.md       (215 Qs)
│   ├── ent.md               (715 Qs)
│   ├── forensic-medicine.md (128 Qs)
│   ├── medicine.md          (585 Qs)
│   ├── microbiology.md      (264 Qs)
│   ├── obstetrics-gynaecology.md (1,060 Qs)
│   ├── ophthalmology.md     (272 Qs)
│   ├── orthopaedics.md      (114 Qs)
│   ├── pathology.md         (469 Qs)
│   ├── pediatrics.md        (101 Qs)
│   ├── pharmacology.md      (329 Qs)
│   ├── physiology.md        (574 Qs)
│   ├── psychiatry.md        (167 Qs)
│   ├── radiology.md         (104 Qs)
│   └── surgery.md           (244 Qs)
├── 2025/questions.md       200 Qs (full DigiNerve recall set)
├── 2024/questions.md       306 Qs (DocTutorials Shift 1+2)
├── 2023/questions.md       211 Qs (PrepLadder + Medicoholic PDF)
├── 2022/questions.md       220 Qs (PrepLadder + Medicoholic PDF)
├── 2021/questions.md       227 Qs (PrepLadder recall)
├── 2020/questions.md       390 Qs (Medicoholic PYQ compilation)
├── 2019/questions.md       381 Qs (Medicoholic + nishantbhushan.in PDFs)
├── 2018/questions.md       322 Qs (PrepLadder + Medicoholic PDF)
├── 2017/questions.md       249 Qs (Medicoholic NEET-PG 2017)
├── 2016/questions.md       1,871 Qs (Medicoholic PYQ compilation + firstranker.com)
└── 2015/questions.md       1,846 Qs (Medicoholic PYQ compilation + firstranker.com 2015)
```

**Current totals (as of 2026-05-25, post-expansion):**
- **Year-wise:** 6,223 questions across 2015–2025 (all years covered)
- **Subject-wise:** 7,455 questions across all 19 NBE subjects
- **Grand total:** ~13,550+ entries (year-wise + subject-wise combined)
- **Audit results:** 0 within-file duplicates, all answer-letter conflicts resolved, sequential Q-numbering verified

| Subject | Year-wise | Subject-wise |
|---------|-----------|--------------|
| Anatomy | ~2,300 | 828 |
| Physiology | ~1,900 | 574 |
| Biochemistry | ~1,500 | 462 |
| Pathology | ~1,500 | 469 |
| Microbiology | ~800 | 264 |
| Pharmacology | ~800 | 329 |
| Forensic Medicine | ~200 | 128 |
| Community Medicine | ~900 | 744 |
| Medicine | ~1,500 | 585 |
| Surgery | ~600 | 244 |
| OBG | ~1,600 | 1,060 |
| Paediatrics | ~300 | 101 |
| Orthopaedics | ~200 | 114 |
| ENT | ~1,600 | 715 |
| Ophthalmology | ~700 | 272 |
| Dermatology | ~500 | 215 |
| Psychiatry | ~400 | 167 |
| Radiology | ~300 | 104 |
| Anaesthesia | ~100 | 80 |

**Remaining gaps:** 2021 year file (227 recall only, no official answer key PDF found).

## Question Format

Each question uses a collapsible answer block — answers stay hidden until you
click, so a single file works as a self-test:

~~~markdown
### Q1 — Short topic label

Question stem here.

- A. Option one
- B. Option two
- C. Option three
- D. Option four

<details><summary>Answer</summary>

**B. Option two** — One-line mechanism / high-yield fact.

</details>
~~~

Within a year file, questions are grouped under `## Subject` headings.

## How to Study

- Open `2024/questions.md` (or any year).
- Read the stem; pick your answer mentally.
- Click "Answer" to reveal.
- Use the year `index.md` to track which year you've covered.

## Adding More Questions

Use [`template.md`](template.md) as a starting block. Drop new questions into
the relevant year's `questions.md` under the right subject heading. Renumber
within the section. Keep explanations one or two lines.

## Subjects (NBE NEET-PG Curriculum)

Anatomy · Physiology · Biochemistry · Pathology · Microbiology · Pharmacology · Forensic Medicine & Toxicology · Community Medicine (PSM) · General Medicine · General Surgery · Obstetrics & Gynaecology · Paediatrics · Orthopaedics · ENT · Ophthalmology · Dermatology · Psychiatry · Radiology · Anaesthesia
