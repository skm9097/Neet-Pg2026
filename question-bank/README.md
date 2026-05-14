# NEET-PG Question Bank

Recall-based question collection organized by year and subject. Questions are contributed from memory by candidates after each exam sitting — no copyrighted content is reproduced here.

## Folder Structure

```
question-bank/
├── template.md          ← Copy this when adding questions
├── 2024/
│   ├── index.md         ← Year summary (total Qs, subject-wise count)
│   ├── anatomy.md
│   ├── physiology.md
│   └── ...
├── 2023/
└── ...
```

## Question Schema

Each subject file is a flat list of questions using this format:

~~~markdown
## Q{n} — {Short topic label}

> **Subject:** Anatomy | **Year:** 2024 | **Difficulty:** Medium | **Repeat:** No

{Question stem — clinical vignette or direct concept question}

- A. Option one
- B. Option two
- C. Option three
- D. Option four

<details>
<summary>Answer</summary>

**Correct Answer: B**

**Explanation:** One or two sentences explaining the correct answer.

**High-Yield Fact:** The single most important takeaway from this question.

</details>

---
~~~

Use `<details>` so the answer is hidden by default while studying.

## Subjects Covered (NBE NEET-PG Curriculum)

| Code | Subject |
|------|---------|
| AN | Anatomy |
| PY | Physiology |
| BI | Biochemistry |
| PA | Pathology |
| MI | Microbiology |
| PH | Pharmacology |
| FM | Forensic Medicine & Toxicology |
| CM | Community Medicine (PSM) |
| GM | General Medicine |
| GS | General Surgery |
| OG | Obstetrics & Gynaecology |
| PE | Paediatrics |
| OR | Orthopaedics |
| EN | ENT |
| OP | Ophthalmology |
| DV | Dermatology & Venereology |
| PS | Psychiatry |
| RD | Radiology & Imaging |
| AN2 | Anaesthesia |

## Contributing

1. Copy `template.md` into the correct `{year}/{subject}.md` file.
2. Add questions at the bottom of the file, incrementing the question number.
3. Mark `**Repeat: Yes**` if the same concept appeared in a prior year.
4. Keep explanations concise — one mechanism, one key fact.
5. Open a PR against `main`; the `claude/` prefix branches are for automated work.

## Naming Conventions

Subject file names (lowercase, hyphenated):

`anatomy.md` · `physiology.md` · `biochemistry.md` · `pathology.md` · `microbiology.md` · `pharmacology.md` · `forensic-medicine.md` · `community-medicine.md` · `general-medicine.md` · `general-surgery.md` · `obs-gynae.md` · `paediatrics.md` · `orthopaedics.md` · `ent.md` · `ophthalmology.md` · `dermatology.md` · `psychiatry.md` · `radiology.md` · `anaesthesia.md`
