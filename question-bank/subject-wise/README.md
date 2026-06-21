# Subject-Wise PYQ Pool

Multi-year question pools grouped by subject, drawn from PrepLadder, DigiNerve, Medicoholic PDFs, DocTutorials, firstranker.com, and coaching-site recall compilations. Questions span NEET-PG/AIPGMEE 2015–2025.

Each subject file contains:
1. **Curated High-Yield section** — hand-picked PrepLadder/DigiNerve questions, multi-year pooled
2. **Year-by-year pool** — complete year-wise bank merged in under `## Year YYYY` headings

Use these files for focused subject revision; for full-paper simulation by exam year see `../20XX/questions.md`.

---

## Files & Question Counts

| File | Subject | Total Qs | Curated | Year-Pool | Missing Years |
|------|---------|-----------|---------|-----------|---------------|
| [anaesthesia.md](anaesthesia.md) | Anaesthesia | 79 | 40 | 39 | 2022 |
| [anatomy.md](anatomy.md) | Anatomy | 824 | 98 | 726 | — |
| [biochemistry.md](biochemistry.md) | Biochemistry | 444 | 50 | 394 | — |
| [community-medicine.md](community-medicine.md) | Community Medicine / PSM | 743 | 260 | 483 | — |
| [dermatology.md](dermatology.md) | Dermatology | 221 | 39 | 182 | 2017, 2018 |
| [ent.md](ent.md) | ENT | 721 | 50 | 671 | 2018 |
| [forensic-medicine.md](forensic-medicine.md) | Forensic Medicine & Toxicology | 134 | 65 | 69 | 2017, 2018 |
| [medicine.md](medicine.md) | General Medicine | 602 | 50 | 552 | — |
| [microbiology.md](microbiology.md) | Microbiology | 269 | 50 | 219 | — |
| [obstetrics-gynaecology.md](obstetrics-gynaecology.md) | Obstetrics & Gynaecology | 1,063 | 706 | 357 | — |
| [ophthalmology.md](ophthalmology.md) | Ophthalmology | 281 | 60 | 221 | 2018 |
| [orthopaedics.md](orthopaedics.md) | Orthopaedics | 121 | 60 | 61 | — |
| [pathology.md](pathology.md) | Pathology | 515 | 40 | 475 | — |
| [pediatrics.md](pediatrics.md) | Paediatrics | 125 | 40 | 85 | 2015, 2016, 2018 |
| [pharmacology.md](pharmacology.md) | Pharmacology | 374 | 50 | 324 | — |
| [physiology.md](physiology.md) | Physiology | 563 | 100 | 463 | — |
| [psychiatry.md](psychiatry.md) | Psychiatry | 174 | 40 | 134 | — |
| [radiology.md](radiology.md) | Radiology | 106 | 60 | 46 | 2017, 2022 |
| [surgery.md](surgery.md) | General Surgery | 256 | 50 | 206 | — |

**Total: 7,616 subject-wise questions** across all 19 NBE NEET-PG subjects.

---

## High-Weight Subjects (≥10 Qs/paper)

Medicine · Surgery · OBG · Paediatrics ≈ 40–45% of paper. Anatomy, Community Medicine, ENT, Pathology also contribute heavily.

---

## File Structure

Every subject file follows this layout:

```
# {Subject} — Multi-Year PYQ Pool
> {N} questions · NEET-PG YYYY–YYYY · Sources: ...

Navigate: [Curated ↓] · [2015] · [2016] · ... · [2025]

---

## Curated High-Yield         ← high-yield questions from PrepLadder/DigiNerve
### Q1 — Topic label
...

## Year 2015                  ← complete year-pool section
### Q{n} — Topic label
...

## Year 2016
...
```

Topic-organized subjects (OBG, Anaesthesia, Orthopaedics, Forensic Medicine) use clinical topic headings within their curated section rather than a single "Curated" block.

---

## How to Use

- **Subject deep-dive:** Open the subject file, attempt questions in the Curated section, then drill year-by-year
- **Exam simulation:** Use `../20XX/questions.md` files to simulate full papers in subject order
- **Targeted revision:** Jump directly to a year section via the Navigate links at the top of each file

## Adding Questions

Add to the relevant year section (`## Year YYYY`) in the subject file. Renumber sequentially. See `../template.md` for the question format.
