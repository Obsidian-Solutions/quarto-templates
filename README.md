# Quarto Docs Template

A distributable Quarto template for Obsidian Solutions documents. It
produces a clean, professional PDF for print and offline use, plus an
HTML version for reading, from one source file.

The template follows the document standards in the standards library
(UK PDF document standards, LaTeX/Pandoc/Quarto production,
GOV.UK and MOD design-review floors) and the professional conventions
those systems establish: full metadata surface, pagination control,
a classification marking on every page, WCAG-checked contrast, and a
traceable baseline. The identity is our own monochrome brand: a
near-black primary drawn from the website brand colour, with greys
for secondary text and rules. It does not mimic any government
identity.

## Requirements

- Quarto 1.9 or later
- A LaTeX engine (lualatex) on TeX Live 2023 or later
- TeX Gyre Pagella, Montserrat and Liberation Mono fonts
- Optionally `quarto install verapdf` for PDF/A validation

## Use as a template

1. Copy this repository, or clone it and remove the example.
2. Edit `example.qmd`: front matter first, then content.
3. Render with `./render.sh example.qmd`.

The script stamps the baseline (commit and date) into the cover and
footer automatically.

## Use as a Quarto extension

Add the format to any project:

```
quarto add Obsidian-Solutions/quarto-docs-template
```

Then set in the document front matter:

```
format: obsidian-pdf
```

## Use as a submodule

```
git submodule add git@github.com:Obsidian-Solutions/quarto-docs-template.git docs/template
```

The extension lives in `_extensions/`, so a submodule or a copy of
this repository both work with any Quarto project.

## Front matter

Populate the full metadata surface. The fields feed the cover, the
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
| review-date | Review date on the cover |
| keywords | Search terms |
| abstract | Summary, on its own page in the front matter |
| lang | Language, set to en-GB |
| watermark | Diagonal watermark on every page (for example "Commercial in Confidence") |
| draft | `true` renders a review copy: watermark DRAFT, status prefixed in the classification line |
| approver | Adds a document approval page after the cover |
| approver-role | Role of the approver, on the approval page |
| approval-date | Date of approval, on the approval page |

Set `baseline` manually only if you render without `render.sh`.

## PDF/A

The format renders PDF/A-2b by default (`pdf-standard: [a-2b]` in
`_extension.yml`). The render validates automatically when veraPDF is
installed:

```
quarto install verapdf
```

The PDF/A requirement is archival: the document carries its reference,
version, baseline and confidentiality in the PDF metadata, so a file
is traceable without opening it.

## Output

- **PDF**: branded cover page, optional approval page, abstract, and
  contents each on their own page, roman-numbered front matter and
  arabic body, numbered sections, running header and footer with the
  classification marking, baseline and page numbers, widow and orphan
  control, optional diagonal watermark.
- **HTML**: the accessible companion for reading, per the HTML-first
  rule.

### Page breaks

The template keeps headings with their content and pins tables in
place, so sections do not split across pages. If a short section
ends at a page boundary with a table, place `\clearpage` before the
section heading in the document.

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

## Fonts

TeX Gyre Pagella (body), Montserrat (headings) and Liberation Mono.
GDS Transport is proprietary and limited to gov.uk domains, and no
public MOD typeface exists, so these are the professional free
fallbacks.

## Licence

MIT. See [LICENSE](LICENSE).
