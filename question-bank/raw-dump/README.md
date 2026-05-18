# raw-dump/

**Purpose:** Garbage-in holding area. Dump everything here — scraped HTML, partial question lists, statement+answer pairs, any format. Nothing in this folder needs to be clean or formatted.

This folder is a retrieval cache so Claude doesn't have to re-fetch the same sources every session. Once raw content is processed into proper MCQ format, it moves to `staging/` for review, then into the main `questions.md` files.

## Folder layout

```
raw-dump/
├── sources.md          ← master log of every known source + fetch status
├── 2015-2018/          ← raw content for years 2015, 2016, 2017, 2018
│   ├── firstranker-2018.md
│   ├── medicoholic-2017-notes.md
│   └── ...
├── 2019-2021/          ← raw content for years 2019, 2020, 2021
└── 2022-2024/          ← raw content for years 2022, 2023, 2024
```

## Naming convention for dump files

```
{source}-{year}-{subject-or-all}.md
```

Examples:
- `firstranker-2021-all.md`
- `examrace-2019-pharmacology.md`
- `oncourse-2018-notes.md`

## Content format inside dump files

No strict format required. Paste verbatim. Add a header block:

```
# Source: [URL or PDF name]
# Fetched: [date]
# Format: [full-MCQ | statement+answer | answer-key-only | mixed]
# Questions found: [approximate count]
# Notes: [anything odd about the source]
```

Then paste raw content below.

## Processing pipeline

```
raw-dump/  →  staging/  →  questions.md (year-wise) / subject-wise/*.md
```

1. raw-dump: verbatim dump, any format
2. staging: formatted MCQ blocks, distractor generation done, awaiting review
3. questions.md: verified, renumbered, merged into main bank
