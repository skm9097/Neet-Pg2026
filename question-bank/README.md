# NEET-PG Question Bank

Recall-based NEET-PG questions reformatted as study notes, organised by year. See [`ATTRIBUTION.md`](ATTRIBUTION.md) for source and usage notice.

## Folder Structure

```
question-bank/
├── ATTRIBUTION.md          Source attribution & use notice
├── STUDY-PLAN.md           Suggested study schedule + how to use this repo
├── template.md             Schema for adding new questions
├── subject-wise/           Multi-year pools across all 19 subjects (~1,695 Qs)
│   ├── README.md
│   ├── anaesthesia.md       (40 Qs)
│   ├── anatomy.md           (99 Qs)
│   ├── biochemistry.md      (50 Qs)
│   ├── community-medicine.md (260 Qs)
│   ├── dermatology.md       (40 Qs)
│   ├── ent.md               (50 Qs)
│   ├── forensic-medicine.md (65 Qs)
│   ├── medicine.md          (50 Qs)
│   ├── microbiology.md      (50 Qs)
│   ├── obstetrics-gynaecology.md (491 Qs)
│   ├── ophthalmology.md     (60 Qs)
│   ├── orthopaedics.md      (60 Qs)
│   ├── pathology.md         (40 Qs)
│   ├── pediatrics.md        (40 Qs)
│   ├── pharmacology.md      (50 Qs)
│   ├── physiology.md        (100 Qs)
│   ├── psychiatry.md        (40 Qs)
│   ├── radiology.md         (60 Qs)
│   └── surgery.md           (50 Qs)
├── 2025/questions.md       200 Qs (full DigiNerve recall set)
├── 2024/questions.md       306 Qs (DocTutorials Shift 1+2)
├── 2023/questions.md       212 Qs (PrepLadder + Medicoholic PDF)
├── 2022/questions.md       222 Qs (PrepLadder + Medicoholic PDF)
├── 2021/questions.md       227 Qs (PrepLadder recall)
├── 2020/questions.md       390 Qs (Medicoholic PYQ compilation)
├── 2019/questions.md       401 Qs (Medicoholic + nishantbhushan.in PDFs)
├── 2018/questions.md       348 Qs (PrepLadder + Medicoholic PDF)
├── 2017/questions.md       258 Qs (Medicoholic PYQ compilation)
├── 2016/questions.md       153 Qs (Medicoholic PYQ compilation)
└── 2015/questions.md       168 Qs (Medicoholic PYQ compilation)
```

**Current totals (as of 2026-05-23):**
- **Year-wise:** 2,885 questions across 2015–2025 (all years covered)
- **Subject-wise:** 1,695 questions across all 19 NBE subjects
- **Combined unique:** ~4,000+ distinct questions

| Subject | Year-wise | Subject-wise |
|---------|-----------|--------------|
| Anatomy | ~311 | 99 |
| Physiology | ~269 | 100 |
| Biochemistry | ~143 | 50 |
| Pathology | ~152 | 40 |
| Microbiology | ~132 | 50 |
| Pharmacology | ~135 | 50 |
| Forensic Medicine | ~80 | 65 |
| Community Medicine | ~257 | 260 |
| Medicine | ~275 | 50 |
| Surgery | ~127 | 50 |
| OBG | ~317 | 491 |
| Paediatrics | ~82 | 40 |
| Orthopaedics | ~63 | 60 |
| ENT | ~162 | 50 |
| Ophthalmology | ~68 | 60 |
| Dermatology | ~56 | 40 |
| Psychiatry | ~68 | 40 |
| Radiology | ~56 | 60 |
| Anaesthesia | ~50 | 40 |

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
