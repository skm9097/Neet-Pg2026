# NEET-PG Question Bank

Recall-based NEET-PG/AIPGMEE questions reformatted as self-testable study notes.  
All questions use collapsible `<details>` answer blocks — answers stay hidden until you click.

See [`ATTRIBUTION.md`](ATTRIBUTION.md) for source and usage notice.

---

## Folder Structure

```
question-bank/
├── ATTRIBUTION.md                   Source attribution & use notice
├── STUDY-PLAN.md                    Suggested 16-week study schedule
├── template.md                      Schema for adding new questions
│
├── subject-wise/                    19 subject files · 7,616 Qs total
│   ├── README.md                    Index + counts + structure guide
│   ├── anaesthesia.md               79 Qs  (40 curated + 39 year-pool)
│   ├── anatomy.md                   824 Qs (98 curated + 726 year-pool)
│   ├── biochemistry.md              444 Qs (50 curated + 394 year-pool)
│   ├── community-medicine.md        743 Qs (260 curated + 483 year-pool)
│   ├── dermatology.md               221 Qs (39 curated + 182 year-pool)
│   ├── ent.md                       721 Qs (50 curated + 671 year-pool)
│   ├── forensic-medicine.md         134 Qs (65 curated + 69 year-pool)
│   ├── medicine.md                  602 Qs (50 curated + 552 year-pool)
│   ├── microbiology.md              269 Qs (50 curated + 219 year-pool)
│   ├── obstetrics-gynaecology.md    1,063 Qs (706 curated + 357 year-pool)
│   ├── ophthalmology.md             281 Qs (60 curated + 221 year-pool)
│   ├── orthopaedics.md              121 Qs (60 curated + 61 year-pool)
│   ├── pathology.md                 515 Qs (40 curated + 475 year-pool)
│   ├── pediatrics.md                125 Qs (40 curated + 85 year-pool)
│   ├── pharmacology.md              374 Qs (50 curated + 324 year-pool)
│   ├── physiology.md                563 Qs (100 curated + 463 year-pool)
│   ├── psychiatry.md                174 Qs (40 curated + 134 year-pool)
│   ├── radiology.md                 106 Qs (60 curated + 46 year-pool)
│   └── surgery.md                   256 Qs (50 curated + 206 year-pool)
│
├── 2025/questions.md                199 Qs · DigiNerve full recall set
├── 2024/questions.md                305 Qs · DocTutorials Shift 1+2
├── 2023/questions.md                210 Qs · PrepLadder + Medicoholic PDF
├── 2022/questions.md                215 Qs · PrepLadder + Medicoholic PDF
├── 2021/questions.md                346 Qs · PrepLadder recall + DocTutorials merged
├── 2020/questions.md                373 Qs · Medicoholic PYQ compilation
├── 2019/questions.md                356 Qs · Medicoholic + nishantbhushan.in PDFs
├── 2018/questions.md                307 Qs · PrepLadder + Medicoholic PDF
├── 2017/questions.md                249 Qs · Medicoholic NEET-PG 2017
├── 2016/questions.md                1,871 Qs · Medicoholic + firstranker.com actual paper
└── 2015/questions.md                1,846 Qs · Medicoholic + firstranker.com actual paper
```

---

## Totals

| System | Questions | Files | Coverage |
|--------|-----------|-------|----------|
| Year-wise | **6,277** | 11 | NEET-PG 2015–2025 (all years) |
| Subject-wise | **7,616** | 19 | All 19 NBE subjects |
| **Grand total** | **~13,893** | 30 | (overlap: subject-wise includes year pool) |

**Audit status (as of 2026-06-21):**
- 0 within-file duplicates (stem-key deduplicated)
- 0 boilerplate "Source: compilation" explanations — all replaced with real mechanisms
- All answer-letter conflicts resolved
- Sequential Q-numbering verified in all 30 files
- All 19 subject files have consistent headers, accurate Q counts, and navigation links

---

## Cross-Reference: Subject Coverage by Year

| Subject | 2015 | 2016 | 2017 | 2018 | 2019 | 2020 | 2021 | 2022 | 2023 | 2024 | 2025 | Subject-Wise |
|---------|------|------|------|------|------|------|------|------|------|------|------|--------------|
| Anatomy | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | 824 Qs |
| Physiology | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | 563 Qs |
| Biochemistry | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | 444 Qs |
| Pathology | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | 515 Qs |
| Microbiology | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | 269 Qs |
| Pharmacology | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | 374 Qs |
| Forensic Medicine | ✓ | ✓ | — | — | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | 134 Qs |
| Community Medicine | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | 743 Qs |
| Medicine | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | 602 Qs |
| Surgery | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | 256 Qs |
| OBG | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | 1,063 Qs |
| Paediatrics | — | — | ✓ | — | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | 125 Qs |
| Orthopaedics | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | 121 Qs |
| ENT | ✓ | ✓ | ✓ | — | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | 721 Qs |
| Ophthalmology | ✓ | ✓ | ✓ | — | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | 281 Qs |
| Dermatology | ✓ | ✓ | — | — | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | 221 Qs |
| Psychiatry | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | 174 Qs |
| Radiology | ✓ | ✓ | — | ✓ | ✓ | ✓ | ✓ | — | ✓ | ✓ | ✓ | 106 Qs |
| Anaesthesia | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | — | ✓ | ✓ | ✓ | 79 Qs |

> **—** = questions from that year not available for this subject (recall gap or not extracted). Year-wise files always have subjects that were actually recalled.

---

## Question Format

All questions use this collapsible format:

~~~markdown
### Q{n} — Short topic label

Question stem here. For clinical vignettes: age/sex, presentation, findings, then question.

- A. Option one
- B. Option two
- C. Option three
- D. Option four

<details><summary>Answer</summary>

**B. Option two** — One-line mechanism / high-yield fact.

</details>
~~~

Within **year-wise files**: questions are grouped under `## Subject` headings (Anatomy, Physiology, …).  
Within **subject-wise files**: questions are grouped under `## Curated High-Yield` then `## Year YYYY` sections.

---

## How to Study

### Year-wise mode (exam simulation)
1. Open any `20XX/questions.md`
2. Work through all subjects in order (simulates the real paper)
3. Click "Answer" only after committing to a choice
4. Track coverage with the year's `index.md`

**Best for:** Final 30 days, mock-test rhythm, getting a feel for difficulty trend

### Subject-wise mode (deep revision)
1. Open `subject-wise/{subject}.md`
2. Use the navigation links at the top to jump between the Curated section and year pools
3. Drill high-yield curated Qs first, then year-by-year to spot recurring patterns

**Best for:** Mid-preparation, subject-by-subject consolidation, spotting repeat questions

### Priority order for 90-day prep
1. **High-weight subjects first:** Medicine, Surgery, OBG, Paediatrics (40–45% of paper)
2. **High-yield-per-hour subjects:** Forensic Medicine, Psychiatry, Radiology, Anaesthesia
3. **High-volume but manageable:** Anatomy (824 Qs), ENT (721 Qs), Community Medicine (743 Qs)
4. **Fill gaps with year-wise drilling** of 2022–2025 (most recent exam patterns)

---

## Negative Marking Calculus (+4/−1)

| Situation | Expected Value | Decision |
|-----------|---------------|----------|
| Complete blind guess (no elimination) | +0.25 | Attempt — marginally positive |
| 1 option eliminated | +0.67 | Attempt |
| 2 options eliminated | +1.50 | Always attempt |
| 3 options eliminated | +3.00 | Always attempt |

**Rule:** Attempt every question where you can eliminate ≥1 option.

---

## Adding Questions

Use [`template.md`](template.md) as the format reference. Drop questions into:
- The relevant year file under the correct `## Subject` heading (year-wise)
- The relevant subject file under the correct `## Year YYYY` section (subject-wise)

Keep both systems in sync — if you add to year-wise, also add to subject-wise.

---

## Subjects (19 NBE NEET-PG Curriculum)

Anatomy · Physiology · Biochemistry · Pathology · Microbiology · Pharmacology · Forensic Medicine & Toxicology · Community Medicine (PSM) · General Medicine · General Surgery · Obstetrics & Gynaecology · Paediatrics · Orthopaedics · ENT · Ophthalmology · Dermatology · Psychiatry · Radiology · Anaesthesia
