# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with this repository.

## Project Overview

**Neet-Pg2026** is a personal NEET-PG 2026 exam preparation repository owned by `skm9097`. The goal is to build the most comprehensive question bank possible — accumulating all recall-based NEET-PG previous year questions (2015–2025), organising them as a self-testing Markdown question bank, and enabling high-yield active-recall study.

The user is sitting NEET-PG 2026 with roughly 90 days remaining from the point of first setup. They have already studied books and watched video lectures once (passively). The challenge is reactivating that knowledge efficiently and shifting to MCQ-based retrieval practice.

MIT-licensed. Dev branch: `claude/add-claude-documentation-1xfan`. Stable: `main`.

---

## Exam Facts to Keep in Mind

- **Format:** 200 MCQs, 3.5 hours, computer-based
- **Marking:** +4 correct / −1 wrong (no marks for unanswered)
- **Subjects:** 19 NBE subjects (see list below)
- **Rank-based:** percentile vs. ~2 lakh candidates — competitive, not pass/fail
- **Trend:** Questions shifting toward clinical vignettes and image-based — application > rote recall
- **High-weight subjects:** Medicine, Surgery, OBG, Paediatrics ≈ 40–45% of paper
- **High yield per hour:** Forensic Medicine, Psychiatry, Radiology, Anaesthesia (short subjects, high payoff)

---

## Repository Structure

```
Neet-Pg2026/
├── CLAUDE.md                        ← this file
├── README.md
├── LICENSE
└── question-bank/
    ├── README.md                    ← folder structure, question counts, how to study
    ├── ATTRIBUTION.md               ← source attribution & copyright notice
    ├── STUDY-PLAN.md                ← 16-week phased study schedule
    ├── template.md                  ← schema for adding new questions
    │
    ├── subject-wise/                ← multi-year pools, one file per subject (7,494 Qs total)
    │   ├── README.md
    │   ├── anaesthesia.md           (79 Qs)
    │   ├── anatomy.md               (824 Qs)
    │   ├── biochemistry.md          (444 Qs)
    │   ├── community-medicine.md    (744 Qs)
    │   ├── dermatology.md           (221 Qs)
    │   ├── ent.md                   (721 Qs)
    │   ├── forensic-medicine.md     (134 Qs)
    │   ├── medicine.md              (602 Qs)
    │   ├── microbiology.md          (269 Qs)
    │   ├── obstetrics-gynaecology.md (1063 Qs)
    │   ├── ophthalmology.md         (281 Qs)
    │   ├── orthopaedics.md          (121 Qs)
    │   ├── pathology.md             (466 Qs)
    │   ├── pediatrics.md            (125 Qs)
    │   ├── pharmacology.md          (328 Qs)
    │   ├── physiology.md            (562 Qs)
    │   ├── psychiatry.md            (167 Qs)
    │   ├── radiology.md             (102 Qs)
    │   └── surgery.md               (241 Qs)
    │
    ├── 2025/questions.md            ← 199 Qs (full DigiNerve recall set)
    ├── 2024/questions.md            ← 305 Qs (DocTutorials Shift 1+2)
    ├── 2023/questions.md            ← 210 Qs (PrepLadder + Medicoholic)
    ├── 2022/questions.md            ← 215 Qs (PrepLadder + Medicoholic)
    ├── 2021/questions.md            ← 346 Qs (PrepLadder recall + DocTutorials merged)
    ├── 2020/questions.md            ← 373 Qs (Medicoholic PYQ)
    ├── 2019/questions.md            ← 356 Qs (Medicoholic + nishantbhushan.in)
    ├── 2018/questions.md            ← 307 Qs (PrepLadder + Medicoholic)
    ├── 2017/questions.md            ← 249 Qs (Medicoholic NEET-PG 2017)
    ├── 2016/questions.md            ← 1,871 Qs (Medicoholic PYQ compilation + firstranker.com)
    ├── 2015/questions.md            ← 1,846 Qs (Medicoholic PYQ compilation + firstranker.com 2015)
    │
    ├── staging/                     ← unverified extracted questions pending review
    │   └── README.md
    │
    └── raw-dump/                    ← raw scraped content, any format, unprocessed
        ├── README.md
        ├── sources.md               ← master list of all known sources with status
        ├── 2015-2018/               ← raw content for old years
        ├── 2019-2021/               ← raw content for mid years
        └── 2022-2024/               ← raw content for recent years
```

**Current totals (as of 2026-06-17, post-Phase-3 cleanup):**
- Year-wise: 6,277 questions (2015–2025, all years covered, sequentially numbered, 0 within-file duplicates)
- Subject-wise: 7,494 questions across all 19 NBE subjects (full year-wise pool merged in; +55 NEET-PG 2018–2023 PYQs added 2026-06-16; +51 more added 2026-06-17)
- Grand total: ~13,771+ entries across year-wise + subject-wise
- Gap: 2021 (346 Qs after DocTutorials merge; still no answer-keyed official PDF)
- OBG: 1,063 Qs (most complete subject, extensively expanded)
- Anatomy: 824 Qs (year-wise 2015+2016 Medicoholic + firstranker.com actual papers merged in)
- Community Medicine: 744 Qs, ENT: 707 Qs
- Quality: subject headings standardized; 0 cross-file answer conflicts; image-only and garbled-OCR stems removed; 3,311 boilerplate `Source: … compilation` explanations replaced with real one-line mechanisms (6,487 file locations updated)

---

## Study Strategy (Owner's Context)

The owner has ~90 days to exam. Strategy is reactivation, not relearning from zero.

### Priority order for Claude when building/expanding the question bank:
1. **2021 year gap** — Only 227 recall questions; no official PDF source with answer key found. nishantbhushan.in has a 2021 PDF at `https://www.nishantbhushan.in/_files/ugd/37999e_086d33f1c86d4f638c453b8919f2f98c.pdf` (download manually — not WebFetch-accessible). Also 2022 PDF at `...37999e_e1759464937f45c988f8c41df8cf0423.pdf`.
2. **Subject-wise depth** — All subjects now have 73–661 Qs (full year-wise pool merged in). No critically thin subjects remain.
3. **Quality improvements** — Some year-wise questions have keyword misclassification by subject; consider re-sorting by subject for easier subject-wise study.

### Active recall beats passive reading
The collapsible `<details><summary>Answer</summary>` blocks in every `.md` file are the core UX. Users open a file, attempt answers mentally, then click to reveal. Never put the answer inline.

### Negative marking calculus (+4/−1)
- Blind guess EV: +0.25 (marginally positive — always attempt)
- One option eliminated: +0.66
- Two options eliminated: +1.5
- Rule: Attempt every question where you can eliminate ≥1 option

---

## Known Question Sources (for future scraping)

### HTML sources (fetchable, no login required)
| Source | Years | Notes |
|--------|-------|-------|
| diginervemedia.com | 2025 | Full 200 Qs fetched ✅ |
| prepladder.com | multi | Subject-wise PYQ pages, 5-year pools |
| firstranker.com | 2018–2024 | HTML question papers, try `/neetpg/neet-pg-YYYY-question-paper/` |
| examrace.com | multi | Has MCQ pages for NEET PG |
| edurev.in | multi | Community-uploaded papers |
| mockers.in | multi | Practice test platform |

### PDF-only sources (cannot WebFetch; download manually)
| Source | Years | Notes |
|--------|-------|-------|
| medicoholic.com | 2015–2024 | PDFs of official papers with answer keys |
| nishantbhushan.in | 2015–2018 | AIPGMEE/NEET-PG PDFs |
| oncourse.ai | 2015–2024 | Claims large question counts (login required for full access) |
| scribd.com | multi | NEET-PG-PYT-2018-to-2022 doc (ID: 626293960) |

### Formats encountered
- **Full MCQ** (stem + 4 options + answer): Ready to add directly after formatting
- **Statement + answer only** (no A/B/C/D): Add to `raw-dump/`, then generate 3 plausible distractors, stage in `staging/`, review before merging
- **Answer key only** (Q number → correct letter): Not useful without question text

---

## Workflow: Adding New Questions

### From a clean HTML source
1. WebFetch the URL → extract questions in the template format
2. Add directly to the appropriate year `questions.md` under the correct `## Subject` heading
3. Renumber within section; keep answers one or two lines

### From a PDF or statement+answer source
1. Dump raw content to `raw-dump/YYYY/[source-name].md`
2. Format into proper MCQ (generate distractors if needed) in `staging/YYYY-[subject].md`
3. Review staging content for accuracy
4. Merge into `question-bank/YYYY/questions.md`

### Question format (always use this)
```markdown
### Q{n} — Topic label

Question stem here.

- A. Option one
- B. Option two
- C. Option three
- D. Option four

<details><summary>Answer</summary>

**B. Option two** — One-line mechanism / high-yield fact.

</details>
```

---

## 19 NBE NEET-PG Subjects

Anatomy · Physiology · Biochemistry · Pathology · Microbiology · Pharmacology · Forensic Medicine & Toxicology · Community Medicine (PSM) · General Medicine · General Surgery · Obstetrics & Gynaecology · Paediatrics · Orthopaedics · ENT · Ophthalmology · Dermatology · Psychiatry · Radiology · Anaesthesia

---

## Git Conventions

- **Dev branch:** `claude/add-claude-documentation-1xfan`
- **Stable:** `main`
- Commits: descriptive, e.g. "Add 2022 pharmacology questions (15 Qs from firstranker)"
- Never commit PDFs or binary files — Markdown only
- Push with: `git push -u origin claude/add-claude-documentation-1xfan`
