# NEET-PG Question Bank

Recall-based NEET-PG questions reformatted as study notes, organised by year. See [`ATTRIBUTION.md`](ATTRIBUTION.md) for source and usage notice.

## Folder Structure

```
question-bank/
├── ATTRIBUTION.md          Source attribution & use notice
├── STUDY-PLAN.md           Suggested study schedule + how to use this repo
├── template.md             Schema for adding new questions
├── subject-wise/           Multi-year pools across all 19 subjects (3,792 Qs)
│   ├── README.md                           (index + counts)
│   ├── anaesthesia.md       (77 Qs)
│   ├── anatomy.md           (357 Qs)
│   ├── biochemistry.md      (156 Qs)
│   ├── community-medicine.md (500 Qs)
│   ├── dermatology.md       (73 Qs)
│   ├── ent.md               (176 Qs)
│   ├── forensic-medicine.md (105 Qs)
│   ├── medicine.md          (288 Qs)
│   ├── microbiology.md      (138 Qs)
│   ├── obstetrics-gynaecology.md (661 Qs)
│   ├── ophthalmology.md     (94 Qs)
│   ├── orthopaedics.md      (101 Qs)
│   ├── pathology.md         (154 Qs)
│   ├── pediatrics.md        (100 Qs)
│   ├── pharmacology.md      (147 Qs)
│   ├── physiology.md        (349 Qs)
│   ├── psychiatry.md        (80 Qs)
│   ├── radiology.md         (91 Qs)
│   └── surgery.md           (145 Qs)
├── 2025/questions.md       200 Qs (full DigiNerve recall set)
├── 2024/questions.md       306 Qs (DocTutorials Shift 1+2)
├── 2023/questions.md       211 Qs (PrepLadder + Medicoholic PDF)
├── 2022/questions.md       220 Qs (PrepLadder + Medicoholic PDF)
├── 2021/questions.md       227 Qs (PrepLadder recall)
├── 2020/questions.md       390 Qs (Medicoholic PYQ compilation)
├── 2019/questions.md       381 Qs (Medicoholic + nishantbhushan.in PDFs)
├── 2018/questions.md       322 Qs (PrepLadder + Medicoholic PDF)
├── 2017/questions.md       258 Qs (Medicoholic PYQ compilation)
├── 2016/questions.md       153 Qs (Medicoholic PYQ compilation)
└── 2015/questions.md       168 Qs (Medicoholic PYQ compilation)
```

**Current totals (as of 2026-05-24, post-expansion):**
- **Year-wise:** 2,836 questions across 2015–2025 (all years covered)
- **Subject-wise:** 3,792 questions across all 19 NBE subjects
- **Combined unique:** ~5,000+ distinct stems
- **Audit results:** 0 within-file duplicates, all answer-letter conflicts resolved, sequential Q-numbering verified across all years

| Subject | Year-wise | Subject-wise |
|---------|-----------|--------------|
| Anatomy | ~311 | 357 |
| Physiology | ~269 | 349 |
| Biochemistry | ~143 | 156 |
| Pathology | ~152 | 154 |
| Microbiology | ~132 | 138 |
| Pharmacology | ~135 | 147 |
| Forensic Medicine | ~80 | 105 |
| Community Medicine | ~257 | 500 |
| Medicine | ~275 | 288 |
| Surgery | ~127 | 145 |
| OBG | ~317 | 661 |
| Paediatrics | ~82 | 100 |
| Orthopaedics | ~63 | 101 |
| ENT | ~162 | 176 |
| Ophthalmology | ~68 | 94 |
| Dermatology | ~56 | 73 |
| Psychiatry | ~68 | 80 |
| Radiology | ~56 | 91 |
| Anaesthesia | ~50 | 77 |

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
