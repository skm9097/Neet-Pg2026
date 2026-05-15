# NEET-PG Question Bank

Recall-based NEET-PG questions reformatted as study notes, organised by year. See [`ATTRIBUTION.md`](ATTRIBUTION.md) for source and usage notice.

## Folder Structure

```
question-bank/
├── ATTRIBUTION.md          Source attribution & use notice
├── template.md             Schema for adding new questions
├── subject-wise/           Multi-year pools grouped by subject (192 Qs)
│   ├── README.md
│   ├── anatomy.md
│   ├── biochemistry.md
│   ├── community-medicine.md
│   ├── dermatology.md
│   ├── ent.md
│   ├── medicine.md
│   ├── microbiology.md
│   ├── pathology.md
│   ├── pediatrics.md
│   ├── psychiatry.md
│   └── surgery.md
├── 2025/
│   ├── index.md            Year overview
│   └── questions.md        All 200 NEET-PG 2025 recall questions
├── 2024/
│   ├── index.md
│   └── questions.md
├── 2023/
│   ├── index.md
│   └── questions.md
├── ...
└── 2015/                   (scaffold only — no public recall set)
    └── index.md
```

Compiled `questions.md` files currently exist for **2019–2025**. The 2025 file
contains the complete 200-question paper. The `subject-wise/` folder has ~192
questions spanning 2019–2024 across 11 subjects. The 2015–2018 folders contain
scaffolded `index.md` only (no public HTML recall sets found for those years).

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
