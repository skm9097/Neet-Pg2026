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
    ├── subject-wise/                ← multi-year pools, one file per subject (~400 Qs total)
    │   ├── README.md
    │   ├── anaesthesia.md           (27 Qs)
    │   ├── anatomy.md               (20 Qs)
    │   ├── biochemistry.md          (20 Qs)
    │   ├── community-medicine.md    (222 Qs)
    │   ├── dermatology.md           (20 Qs)
    │   ├── ent.md                   (20 Qs)
    │   ├── forensic-medicine.md     (35 Qs)
    │   ├── medicine.md              (20 Qs)
    │   ├── microbiology.md          (20 Qs)
    │   ├── obstetrics-gynaecology.md (30 Qs)
    │   ├── ophthalmology.md         (15 Qs)
    │   ├── orthopaedics.md          (40 Qs)
    │   ├── pathology.md             (18 Qs)
    │   ├── pediatrics.md            (14 Qs)
    │   ├── pharmacology.md          (10 Qs)
    │   ├── physiology.md            (16 Qs)
    │   ├── psychiatry.md            (20 Qs)
    │   ├── radiology.md             (15 Qs)
    │   └── surgery.md               (20 Qs)
    │
    ├── 2025/questions.md            ← 200 Qs (full DigiNerve recall set)
    ├── 2024/questions.md            ← 306 Qs (DocTutorials Shift 1+2)
    ├── 2023/questions.md            ← 211 Qs (PrepLadder + Medicoholic)
    ├── 2022/questions.md            ← 220 Qs (PrepLadder + Medicoholic)
    ├── 2021/questions.md            ← 227 Qs (PrepLadder recall)
    ├── 2020/questions.md            ← 390 Qs (Medicoholic PYQ)
    ├── 2019/questions.md            ← 381 Qs (Medicoholic + nishantbhushan.in)
    ├── 2018/questions.md            ← 322 Qs (PrepLadder + Medicoholic)
    ├── 2017/questions.md            ← 258 Qs (Medicoholic PYQ)
    ├── 2016/questions.md            ← 153 Qs (Medicoholic PYQ)
    ├── 2015/questions.md            ← 168 Qs (Medicoholic PYQ)
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

**Current totals (as of 2026-05-24, post-audit):**
- Year-wise: 2,836 questions (2015–2025, all years covered, sequentially numbered, 0 within-file duplicates)
- Subject-wise: 1,693 questions across all 19 NBE subjects
- Combined unique: ~3,900 distinct stems
- Gap: 2021 (227 Qs recall only, no official PDF source with answer key)
- PSM/Community Medicine: 260 Qs (most complete subject)
- OBG: 491 Qs (subject-wise, extensively expanded)
- Anatomy/Physiology: 99/100 Qs (subject-wise)
- Quality: subject headings standardized (Paediatrics, Community Medicine); 3 cross-file answer conflicts resolved; 2 malformed answer blocks fixed

---

## Study Strategy (Owner's Context)

The owner has ~90 days to exam. Strategy is reactivation, not relearning from zero.

### Priority order for Claude when building/expanding the question bank:
1. **Subject-wise depth** — Low-count subjects need expansion: Pathology 18 Qs, Biochemistry/Dermatology/ENT/Medicine/Microbiology/Psychiatry/Surgery 20 Qs each, Pharmacology 25 Qs, Paediatrics 14 Qs. Community Medicine (260 Qs), OBG (491 Qs), Physiology (100 Qs), Anatomy (99 Qs) are well-developed.
2. **2021 year gap** — Only 227 recall questions; no official PDF source with answer key found. Try PrepLadder or other sources.
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
