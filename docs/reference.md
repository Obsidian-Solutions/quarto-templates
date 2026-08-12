# Reference

This file is the reference manual for the Obsidian Solutions Quarto
template. The README teaches and explains; this file describes the
machinery. Each section is the full detail for one part of the
template.

## Front matter

Populate the metadata surface. The fields feed the cover, the
running header, the footer, and the PDF metadata.

| Field | Purpose |
|---|---|
| title | Document title |
| subtitle | Subtitle |
| author | Author or organisation |
| date | Publication date |
| reference | Document reference, shown as the document id |
| version | Document version |
| confidentiality | Classification marking, shown top and bottom of every page |
| short-title | Running header title |
| doc-type | Label above the title on the cover (for example "Policy Document") |
| edition | Edition line on the cover |
| review-date | Review date on the cover; if in the past, the render carries a REVIEW OVERDUE warning |
| supersedes | Document this one replaces, shown on the cover as "Supersedes:" |
| attach | List of files embedded in the PDF/A-4f archive, each with `source`, `description`, `mimetype` |
| sections-new-page | `true` starts each numbered section on a fresh page (formal documents; short documents flow better without it) |
| keywords | Search terms |
| abstract | Summary, on its own page in the front matter |
| lang | Language, set to en-GB |
| watermark | Diagonal watermark on every page (for example "Commercial in Confidence") |
| draft | `true` renders a review copy: watermark DRAFT, status prefixed in the classification line |
| approver | Adds a document approval page after the cover |
| approver-role | Role of the approver, on the approval page |
| approval-date | Date of approval, on the approval page |
| proprietor | Sole-trader trading-name disclosure (CA 2006 Part 41): the owner's name and service address, shown in the footer. Required by law for a business trading under a name other than the owner's true name |
| gscp | `true` enables the optional Government Security Classifications validation (see the GSCP section below). Default off |
| ste | `false` opts a document out of the controlled-language gate, for example to quote external material verbatim. Default on |

`attach` entries must exist in the working directory at render time.
`render.sh` generates `manifest.json` with the document, baseline and
render date; the example attaches it alongside the source.

Set `baseline` manually only if you render without `render.sh`.

## Formats

The template contributes eight formats. Each example source file
declares its full format family in the front matter, so one render
command per file produces the whole family with no content loss.

| Format | Output | Notes |
|---|---|---|
| `obsidian-pdf` | PDF/A-4f | branded cover, approval page, abstract, revision history, contents each on their own page, roman front matter, arabic body, numbered sections, classification in header and footer, baseline and page numbers, widow and orphan control, optional watermark |
| `obsidian-html` | HTML | accessible companion, light and dark themes, WCAG AAA contrast |
| `obsidian-docx` | DOCX | client-editable companion, house style, no LaTeX-only front matter |
| `obsidian-epub` | EPUB | e-reader distribution, classification banner, brand cover image |
| `obsidian-revealjs` | HTML deck | house palette and typography, classification banner, `##` for slides |
| `obsidian-beamer` | PDF deck | 16:9, classification footline on every slide including the title |
| `obsidian-pptx` | PPTX | editable deck, classification marking on every slide |
| `obsidian-dashboard` | HTML | live-data dashboard, html theme, classification filter only |

Quarto can also emit plain formats (markdown, LaTeX, ODT, Typst,
ipynb) with `quarto render ... --to <format>`. Those carry no
Obsidian Solutions branding: the filters, partials, and themes are
format-specific, and a format with no `obsidian-*` equivalent renders
with Quarto's defaults.

## Brand

The palette is monochrome, drawn from the website brand colour and
the functional grey scale proven by the GOV.UK and NHS design
systems:

| Role | Hex | Contrast on white |
|---|---|---|
| Primary text | `#121212` | 16.8:1 |
| Secondary text | `#484949` | 9.0:1 (passes AAA) |
| Rules and hairlines | `#cecece` | decorative |

The greys are functional tokens, not a copied identity. Change the
`\definecolor` block in `include-in-header.tex` to rebrand.

## Verification gates

`render.sh` runs three gates on every render, and the CI runs them on
the example document:

1. **Page-overflow gate.** Any `Overfull \hbox` or `\vbox` in the
   LaTeX log fails the render, so no document ships with content
   clipped at a margin.
2. **Controlled-language gate** (`scripts/check-ste.py`). Fails on
   hard violations of the JSP 101 / ASD-STE100 word lists: banned
   words, marketing adjectives, phrasal verbs, modal hedges,
   contractions, American spellings, and em dashes. Long sentences,
   passive voice and semicolons are warnings. Blockquotes are exempt
   (verbatim quoted material), and a document opts out with
   `ste: false` in its front matter.
3. **PDF/UA-2 structure gate** (`scripts/check-pdfua.py`). Fires only
   for UA-2 renders and fails when the tagged structure tree lacks
   heading roles.

Exempt-by-design from the language gate, so the gate measures
documents and not machinery:

- `scripts/check-ste.py` itself: the embedded word list is the source
  the gate checks against.
- `theme*.scss` and `epub.css`: CSS colour tokens and property names
  are not prose.
- Fixed identifiers: `SPDX-License-Identifier`, the `LICENSE`
  filename, `SIL Open Font License`, and the licence URLs in the
  NOTICE files. They are standard strings from their licences.
- `CODE_OF_CONDUCT.md`: the canonical Contributor Covenant text.
  Rewriting it in controlled language would deviate from the
  recognised community standard.
- `_extensions/obsidian/NOTICE`: the remaining hits are the fixed
  identifiers above and table cells that carry licence URLs.

The supply-chain record is `sbom.spdx.json`, generated by
`scripts/make-sbom.py` (stdlib only) and checked for freshness in CI,
so the committed SBOM cannot go stale.

## Optional GSCP classification mode

Set `gscp: true` in the front matter to validate the marking against
the UK Government Security Classifications Policy (GSCP v2.0). The
gate (`filters/classification-gate.lua`):

- accepts `confidentiality` or `classification` (the MOD field name)
- defaults to OFFICIAL when no marking is set
- fails the render on obsolete levels (RESTRICTED, CONFIDENTIAL) or
  values outside the GSCP set
- accepts an OFFICIAL-SENSITIVE reason after a colon, for example
  "OFFICIAL-SENSITIVE: COMMERCIAL"
- warns when SECRET or TOP SECRET is used, because their handling
  requirements are outside what a template can enforce

This mode is for documents that must meet the Government Security
Classifications. The default posture is commercial (free-text
marking), per the standards posture in the README.

## Controlled-language gate

The `ste` front-matter option controls the controlled-language gate
(JSP 101 / ASD-STE100). The gate fails the render on banned words,
marketing adjectives, phrasal verbs, modal hedges, contractions,
American spellings, and em dashes. Blockquotes are exempt: they
carry verbatim quoted material, which the author cannot rewrite.

The gate is the example project's build tooling. `quarto add`
installs only the `_extensions/` directory, so an installed extension
does not carry the script. A user who wants the gate copies
`scripts/check-ste.py` with the example project.
