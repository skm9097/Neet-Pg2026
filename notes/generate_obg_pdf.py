#!/usr/bin/env python3
"""
OBG Question-Engraved Concept Book → PDF generator.

Reads OBG_Concept_Book.md (Markdown) and produces OBG_Concept_Book.pdf
using markdown + weasyprint with custom CSS styling.

Usage:
    pip install markdown pymdown-extensions weasyprint
    python3 generate_obg_pdf.py
"""

import os
import re
import sys
from pathlib import Path

import markdown
from weasyprint import HTML, CSS
from weasyprint.text.fonts import FontConfiguration

HERE = Path(__file__).parent
MD_PATH = HERE / "OBG_Concept_Book.md"
PDF_PATH = HERE / "OBG_Concept_Book.pdf"


def md_to_html(md_text: str) -> str:
    extensions = [
        "tables",
        "fenced_code",
        "attr_list",
        "def_list",
        "admonition",
        "toc",
        "sane_lists",
        "pymdownx.details",
        "pymdownx.tilde",
        "pymdownx.tasklist",
        "pymdownx.superfences",
    ]
    md = markdown.Markdown(
        extensions=extensions,
        extension_configs={
            "toc": {"permalink": False, "toc_depth": "2-3"},
            "pymdownx.tasklist": {"clickable_checkbox": False},
        },
    )
    body = md.convert(md_text)
    return body


CSS_TEXT = """
@page {
    size: A4;
    margin: 18mm 16mm 18mm 16mm;
    @top-right {
        content: "OBG Concept Book";
        font-size: 8pt;
        color: #888;
        font-family: 'DejaVu Sans', sans-serif;
    }
    @bottom-center {
        content: counter(page) " / " counter(pages);
        font-size: 8.5pt;
        color: #555;
        font-family: 'DejaVu Sans', sans-serif;
    }
}

@page :first {
    margin: 0;
    @top-right { content: none; }
    @bottom-center { content: none; }
}

* { box-sizing: border-box; }

html, body {
    font-family: 'Georgia', 'Times New Roman', serif;
    font-size: 10.5pt;
    line-height: 1.45;
    color: #222;
}

h1 {
    font-family: 'DejaVu Sans', 'Helvetica', sans-serif;
    font-size: 22pt;
    color: #1a1a2e;
    border-bottom: 3px solid #e94560;
    padding-bottom: 8px;
    margin-top: 24pt;
    margin-bottom: 14pt;
    page-break-before: always;
    page-break-after: avoid;
}

h1:first-of-type { page-break-before: avoid; }

h2 {
    font-family: 'DejaVu Sans', 'Helvetica', sans-serif;
    font-size: 16pt;
    color: #16213e;
    margin-top: 20pt;
    margin-bottom: 8pt;
    border-bottom: 1.5px solid #c8d6e5;
    padding-bottom: 4px;
    page-break-after: avoid;
}

h3 {
    font-family: 'DejaVu Sans', 'Helvetica', sans-serif;
    font-size: 13pt;
    color: #0f3460;
    margin-top: 14pt;
    margin-bottom: 6pt;
    page-break-after: avoid;
}

h4 {
    font-family: 'DejaVu Sans', 'Helvetica', sans-serif;
    font-size: 11pt;
    color: #16213e;
    margin-top: 10pt;
    margin-bottom: 4pt;
    page-break-after: avoid;
}

p { margin: 4pt 0 6pt 0; }

a { color: #0f3460; text-decoration: none; }
a:hover { text-decoration: underline; }

ul, ol { margin: 4pt 0 8pt 18pt; padding: 0; }
li { margin-bottom: 2pt; }

strong, b { color: #1a1a2e; }

em, i { color: #444; }

code {
    font-family: 'DejaVu Sans Mono', 'Courier New', monospace;
    font-size: 9.5pt;
    background: #f3f3f3;
    padding: 1px 4px;
    border-radius: 3px;
    color: #c7254e;
}

pre {
    background: #f8f8f8;
    border-left: 3px solid #e94560;
    padding: 8px 10px;
    font-size: 9pt;
    overflow-x: auto;
    page-break-inside: avoid;
}

pre code {
    background: none;
    padding: 0;
    color: #333;
}

blockquote {
    border-left: 4px solid #f5a623;
    background: #fff7e0;
    padding: 8px 14px;
    margin: 8pt 0;
    font-style: italic;
    color: #5a4a1f;
    page-break-inside: avoid;
}

hr {
    border: none;
    border-top: 1px solid #cfd8e3;
    margin: 14pt 0;
}

table {
    border-collapse: collapse;
    width: 100%;
    margin: 8pt 0;
    font-size: 9.5pt;
    page-break-inside: avoid;
}

th {
    background: #1a1a2e;
    color: white;
    padding: 6px 8px;
    text-align: left;
    font-family: 'DejaVu Sans', sans-serif;
    font-weight: 600;
    font-size: 9pt;
}

td {
    border: 0.5px solid #d4d4d4;
    padding: 5px 8px;
    vertical-align: top;
}

tr:nth-child(even) td { background: #f7f9fc; }

details {
    background: #d9f0e2;
    border-left: 4px solid #2e7d50;
    padding: 8px 12px;
    margin: 6pt 0;
    border-radius: 3px;
    page-break-inside: avoid;
}

details summary {
    font-weight: bold;
    color: #1b5e3a;
    cursor: pointer;
    font-family: 'DejaVu Sans', sans-serif;
    font-size: 10pt;
}

details[open] summary { margin-bottom: 6pt; }

/* In a printed PDF, <details> doesn't open; force it to be open */
details { display: block; }
details summary::before {
    content: "▸ Answer & Explanation:";
    color: #1b5e3a;
    font-weight: 700;
}
details summary { font-size: 0; }
details summary::before { font-size: 10pt; }
details > *:not(summary) { display: block !important; font-size: 10pt; color: #1a1a2e; }

/* Style for the first H1 (book title) */
h1.cover-title {
    page-break-before: avoid;
    border: none;
    text-align: center;
    color: #1a1a2e;
    margin-top: 30%;
    font-size: 30pt;
}

/* Question headers (### Q123 — Topic) */
h3:has(+ p) { color: #c2185b; }

/* Chapter band */
.chapter-band {
    background: #0f3460;
    color: white;
    padding: 8px 12px;
    margin: 0 0 14pt 0;
    font-family: 'DejaVu Sans', sans-serif;
    font-size: 10pt;
    letter-spacing: 1px;
    text-transform: uppercase;
}

/* Cover page */
.cover {
    page-break-after: always;
    text-align: center;
    padding: 0 20mm;
}

.cover .cover-inner {
    margin-top: 35%;
}

.cover h1.cover-title {
    font-size: 32pt;
    color: #1a1a2e;
    border: none;
    margin: 0 0 12pt 0;
    page-break-before: avoid;
}

.cover .cover-subtitle {
    font-size: 14pt;
    color: #0f3460;
    font-style: italic;
    margin-bottom: 28pt;
}

.cover .cover-meta {
    color: #555;
    font-size: 11pt;
    margin-top: 18pt;
}

.cover .cover-accent {
    color: #e94560;
    font-weight: bold;
    font-size: 12pt;
    margin: 16pt 0;
}

/* Emoji-only headers */
h2:has-text("🎯"), h2:has-text("📊"), h2:has-text("📚") {
    background: linear-gradient(90deg, #16213e, #0f3460);
    color: white;
    padding: 6px 10px;
    border: none;
    margin-top: 16pt;
}
"""


def build_cover() -> str:
    return """
<div class="cover">
  <div class="cover-inner">
    <h1 class="cover-title">OBG Question-Engraved<br/>Concept Book</h1>
    <div class="cover-subtitle">Obstetrics & Gynaecology</div>
    <div class="cover-accent">NEET-PG · INI-CET · FMGE · UPSC CMS</div>
    <div class="cover-meta">
      Built from <strong>1,063 PYQs</strong> · 12 Chapters · 65,000+ words<br/>
      NEET-PG 2026 Edition
    </div>
    <div class="cover-meta" style="margin-top: 60pt; font-style: italic; color: #888;">
      &ldquo;A brilliant senior teaching you the secrets of the exam.&rdquo;
    </div>
  </div>
</div>
"""


def main():
    if not MD_PATH.exists():
        print(f"ERROR: {MD_PATH} not found", file=sys.stderr)
        sys.exit(1)

    print(f"Reading {MD_PATH} ...")
    md_text = MD_PATH.read_text(encoding="utf-8")

    print("Converting Markdown → HTML ...")
    body_html = md_to_html(md_text)

    full_html = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>OBG Concept Book</title>
</head>
<body>
{build_cover()}
{body_html}
</body>
</html>"""

    print(f"Rendering PDF → {PDF_PATH} (this may take 1-2 minutes for 65k words) ...")
    font_config = FontConfiguration()
    html = HTML(string=full_html, base_url=str(HERE))
    css = CSS(string=CSS_TEXT, font_config=font_config)
    html.write_pdf(str(PDF_PATH), stylesheets=[css], font_config=font_config)

    size_kb = PDF_PATH.stat().st_size / 1024
    print(f"\n✓ Done: {PDF_PATH} ({size_kb:.0f} KB)")


if __name__ == "__main__":
    main()
