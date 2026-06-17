# NEET-PG Question Bank

Recall-based NEET-PG questions reformatted as study notes, organised by year. See [`ATTRIBUTION.md`](ATTRIBUTION.md) for source and usage notice.

## Folder Structure

```
question-bank/
├── ATTRIBUTION.md          Source attribution & use notice
├── STUDY-PLAN.md           Suggested study schedule + how to use this repo
├── template.md             Schema for adding new questions
├── subject-wise/           Multi-year pools across all 19 subjects (7,616 Qs)
│   ├── README.md                           (index + counts)
│   ├── anaesthesia.md       (79 Qs)
│   ├── anatomy.md           (824 Qs)
│   ├── biochemistry.md      (444 Qs)
│   ├── community-medicine.md (744 Qs)
│   ├── dermatology.md       (221 Qs)
│   ├── ent.md               (721 Qs)
│   ├── forensic-medicine.md (134 Qs)
│   ├── medicine.md          (602 Qs)
│   ├── microbiology.md      (269 Qs)
│   ├── obstetrics-gynaecology.md (1,063 Qs)
│   ├── ophthalmology.md     (281 Qs)
│   ├── orthopaedics.md      (121 Qs)
│   ├── pathology.md         (515 Qs)
│   ├── pediatrics.md        (125 Qs)
│   ├── pharmacology.md      (374 Qs)
│   ├── physiology.md        (563 Qs)
│   ├── psychiatry.md        (174 Qs)
│   ├── radiology.md         (106 Qs)
│   └── surgery.md           (256 Qs)
├── 2025/questions.md       199 Qs (full DigiNerve recall set)
├── 2024/questions.md       305 Qs (DocTutorials Shift 1+2)
├── 2023/questions.md       210 Qs (PrepLadder + Medicoholic PDF)
├── 2022/questions.md       215 Qs (PrepLadder + Medicoholic PDF)
├── 2021/questions.md       346 Qs (PrepLadder recall + DocTutorials merged)
├── 2020/questions.md       373 Qs (Medicoholic PYQ compilation)
├── 2019/questions.md       356 Qs (Medicoholic + nishantbhushan.in PDFs)
├── 2018/questions.md       307 Qs (PrepLadder + Medicoholic PDF)
├── 2017/questions.md       249 Qs (Medicoholic NEET-PG 2017)
├── 2016/questions.md       1,871 Qs (Medicoholic PYQ compilation + firstranker.com)
└── 2015/questions.md       1,846 Qs (Medicoholic PYQ compilation + firstranker.com 2015)
```

**Current totals (as of 2026-06-17, post-cleanup):**
- **Year-wise:** 6,277 questions across 2015–2025 (all years covered)
- **Subject-wise:** 7,616 questions across all 19 NBE subjects
- **Grand total:** ~13,893+ entries (year-wise + subject-wise combined)
- **Audit results:** 0 within-file duplicates, 0 boilerplate-only explanations, all answer-letter conflicts resolved, sequential Q-numbering verified
- **Phase 3 cleanup:** 3,311 unique stems (6,487 file locations) had boilerplate `Source: … compilation` replaced with real one-line mechanisms via 125 batched expansions

| Subject | Year-wise | Subject-wise |
|---------|-----------|--------------|
| Anatomy | ~2,300 | 824 |
| Physiology | ~1,900 | 563 |
| Biochemistry | ~1,500 | 444 |
| Pathology | ~1,500 | 515 |
| Microbiology | ~800 | 269 |
| Pharmacology | ~800 | 374 |
| Forensic Medicine | ~200 | 134 |
| Community Medicine | ~900 | 744 |
| Medicine | ~1,500 | 602 |
| Surgery | ~600 | 256 |
| OBG | ~1,600 | 1,063 |
| Paediatrics | ~300 | 125 |
| Orthopaedics | ~200 | 121 |
| ENT | ~1,600 | 721 |
| Ophthalmology | ~700 | 281 |
| Dermatology | ~500 | 221 |
| Psychiatry | ~400 | 174 |
| Radiology | ~300 | 106 |
| Anaesthesia | ~100 | 79 |

**Remaining gaps:** 2021 year file relies on DocTutorials + PrepLadder recall; no official answer key PDF found.

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
