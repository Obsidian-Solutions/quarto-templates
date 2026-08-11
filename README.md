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

- Quarto 1.3 or later
- A LaTeX engine (lualatex)
- TeX Gyre Pagella, Montserrat and Liberation Mono fonts

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
| abstract | Summary |
| lang | Language, set to en-GB |

Set `baseline` manually only if you render without `render.sh`.

## Output

- **PDF**: branded cover page, contents on its own page, numbered
  sections, running header and footer with the classification marking,
  baseline and page numbers, widow and orphan control.
- **HTML**: the accessible companion for reading, per the HTML-first
  rule.

### Page breaks

The template keeps headings with their content and pins tables in
place, so sections do not split across pages. If a short section
ends at a page boundary with a table, place `\clearpage` before the
section heading in the document.

For archival copies, enable the PDF/A option in `_extension.yml` and
validate with veraPDF. The default output is not PDF/A.

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
