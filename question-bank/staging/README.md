# staging/

**Purpose:** Questions that have been formatted into proper MCQ format but not yet verified/merged into the main question bank.

Content here comes from `raw-dump/` after processing. Before merging into a year's `questions.md`, check:
- [ ] Question stem is clear and unambiguous
- [ ] All 4 options are plausible (distractors are medically reasonable, not obviously wrong)
- [ ] Correct answer is accurate
- [ ] One-line explanation captures the high-yield mechanism

## File naming

```
{year}-{subject}.md
```

Examples:
- `2022-pharmacology.md`
- `2018-medicine.md`
- `2017-mixed.md` (when subject is unknown)

## Format inside staging files

Use the standard question template:

```markdown
### Q{n} — Topic label

Question stem.

- A. Option one
- B. Option two
- C. Option three
- D. Option four

<details><summary>Answer</summary>

**B. Option two** — High-yield mechanism.

</details>

<!-- SOURCE: firstranker.com/... | CONFIDENCE: high/medium/low | OPTIONS_GENERATED: true/false -->
```

Add the HTML comment with source URL and whether options were AI-generated (needs extra verification if true).

## Merge checklist

When merging a staging file into `questions.md`:
1. Open the target year's `questions.md`
2. Find the correct `## Subject` section
3. Append questions, renumbering sequentially
4. Delete or archive the staging file after merge
5. Update question counts in `question-bank/README.md`
