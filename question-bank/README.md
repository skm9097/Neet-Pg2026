# NEET-PG Question Bank

Recall-based NEET-PG questions reformatted as study notes, organised by year. See [`ATTRIBUTION.md`](ATTRIBUTION.md) for source and usage notice.

## Folder Structure

```
question-bank/
├── ATTRIBUTION.md          Source attribution & use notice
├── STUDY-PLAN.md           Suggested study schedule + how to use this repo
├── template.md             Schema for adding new questions
├── subject-wise/           Multi-year pools across all 19 subjects (~400 Qs)
│   ├── README.md
│   ├── anaesthesia.md       (27 Qs)
│   ├── anatomy.md           (20 Qs)
│   ├── biochemistry.md      (20 Qs)
│   ├── community-medicine.md (20 Qs)
│   ├── dermatology.md       (20 Qs)
│   ├── ent.md               (20 Qs)
│   ├── forensic-medicine.md (35 Qs)
│   ├── medicine.md          (20 Qs)
│   ├── microbiology.md      (20 Qs)
│   ├── obstetrics-gynaecology.md (30 Qs)
│   ├── ophthalmology.md     (15 Qs)
│   ├── orthopaedics.md      (40 Qs)
│   ├── pathology.md         (18 Qs)
│   ├── pediatrics.md        (14 Qs)
│   ├── pharmacology.md      (10 Qs)
│   ├── physiology.md        (16 Qs)
│   ├── psychiatry.md        (20 Qs)
│   ├── radiology.md         (15 Qs)
│   └── surgery.md           (20 Qs)
├── 2025/questions.md       All 200 NEET-PG 2025 recall questions
├── 2024/questions.md       40 Qs (recall)
├── 2023/questions.md       35 Qs (recall)
├── 2022/questions.md       29 Qs (recall)
├── 2021/questions.md       36 Qs (recall)
├── 2020/questions.md       36 Qs (recall)
├── 2019/questions.md       22 Qs (recall, truncated source)
└── 2015–2018/              index.md only (PDF source links provided)
```

**Current totals:**
- **Year-wise:** ~400 questions (2019–2025, with full 200 for 2025)
- **Subject-wise:** ~400 questions across all 19 NBE subjects
- **Combined unique:** ~700 distinct questions

**Gaps (with sources):** 2015–2018 papers exist only as PDFs at
medicoholic.com, nishantbhushan.in, and Oncourse AI — links provided in each
year's `index.md`. Manual download required.

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
