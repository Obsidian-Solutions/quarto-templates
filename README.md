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
| review-date | Review date on the cover; if in the past, the render carries a REVIEW OVERDUE warning |
| supersedes | Document this one replaces, shown on the cover as "Supersedes:" |
| attach | List of files embedded in the PDF/A-4f archive, each with `source`, `description`, `mimetype` |
| keywords | Search terms |
| abstract | Summary, on its own page in the front matter |
| lang | Language, set to en-GB |
| watermark | Diagonal watermark on every page (for example "Commercial in Confidence") |
| draft | `true` renders a review copy: watermark DRAFT, status prefixed in the classification line |
| approver | Adds a document approval page after the cover |
| approver-role | Role of the approver, on the approval page |
| approval-date | Date of approval, on the approval page |

`attach` entries must exist in the working directory at render time.
`render.sh` generates `manifest.json` with the document, baseline and
render date; the example attaches it alongside the source.

Set `baseline` manually only if you render without `render.sh`.

## PDF/A and PDF/UA

The format renders PDF/A-4f by default (`pdf-standard: [a-4f]` in
`_extension.yml`), validated automatically when veraPDF is installed:

```
quarto install verapdf
```

The PDF/A requirement is archival: the document carries its
reference, version and baseline in the XMP `dc:source` field (the
pdfmanagement metadata path drops custom Info keys, so the standard
field carries the control identity), and the full source and control
manifest are embedded as PDF/A-4f attachments. A file is traceable
without opening it, and self-contained without the repository.
PDF/A-4f uses PDF 2.0 and does not require the tagged structure tree,
so the table of contents stays clickable: every entry is a real link
to its section.

### PDF/UA-2 (screen readers)

PDF/UA-2 produces a tagged structure tree for assistive technology.
The current LaTeX toolchain cannot produce PDF/UA-2 and clickable TOC
links at the same time: `\DocumentMetadata` disables hyperref's TOC
link annotations (latex3/tagging-project issue 1157).

The default is the non-accessible version: PDF/A-4f with clickable
TOC links. Use the accessible version only when a client requests it,
as it is rarely needed. To render a document with PDF/UA-2 instead:

1. In `_extension.yml`, change the default to
   `pdf-standard: [a-4f, ua-2]`.
2. Remove `partials/document-metadata.latex` from the
   `template-partials` list, so Quarto's `\DocumentMetadata` is used.
3. Accept that the TOC page will not contain clickable links.

Body cross-references keep working in both modes. Revisit after the
upstream fix: the escape-hatch partial exists so the template can
re-enable PDF/UA-2 without losing links.

#### Known limitation: flat heading structure

Quarto's PDF/UA-2 tagging does not assign heading roles (H1-H6) to
section headings. The KOMA class and the kernel sectioning never
promote sections to headings; tagpdf's namespace mapping is data-only
and nothing reads it. The result is a structure tree of plain
paragraph tags, and veraPDF passes it because it runs only
machine-verifiable checks. This affects every Quarto PDF/UA-2
document, not just this template. LaTeX-side patches (hooks,
`\@sect` redefinitions, tagging sockets) each fail on this toolchain:
compile errors, Hn-contains-P nesting violations, or tree corruption.

`scripts/check-ua.py` is the honest gate. It fails when a UA-2 render
lacks heading roles, so no heading-less document is ever shipped as
accessible. `render.sh` runs it automatically for UA-2 renders. The
upstream fix would be Quarto wiring section-to-heading tagging on
KOMA; revisit this after a Quarto or LaTeX release addresses it.

## Output

- **PDF**: branded cover page, optional approval page, abstract,
  revision history, and contents each on their own page,
  roman-numbered front matter and arabic body, numbered sections,
  running header and footer with the classification marking, baseline
  and page numbers, widow and orphan control, optional diagonal
  watermark.
- **HTML**: the accessible companion for reading, per the HTML-first
  rule.
- **DOCX**: the client-editable companion. Use it when a client needs
  to amend the document. It carries the house style — Palatino
  Linotype body, Montserrat headings, near-black and grey palette,
  booktabs tables, branded header and numbered footer — but not the
  full front-matter machinery (cover, approval page, revision
  history), which is LaTeX-only. The PDF remains the controlled
  record; the DOCX is a working copy.
- **Revealjs** (`obsidian-revealjs`): client presentations. The
  revealjs theme carries the house palette and typography; the
  classification filter marks the deck. Use `##` for slides.
- **Dashboard** (`obsidian-dashboard`): client-facing dashboards for
  live data. Uses the html theme. Only the classification filter
  applies, since review warnings are for documents.

### List of tables and figures

The front matter carries a List of Figures and a List of Tables after
the Contents (JSP 101 layout), in the roman-numbered section. They
render only when the document contains a labelled figure or table.
Disable with `lof: false` / `lot: false` in the front matter.

### Citations

Set `bibliography:` in the front matter to a BibTeX file, then cite
with `@key`. The template bundles a numbered CSL (IEEE style), so
in-text citations render as `[1]` and link to the numbered
References section at the end of the document. The References heading
is listed in the table of contents automatically.

### Appendices

Give a section the `{.appendix}` class to start the appendices:

```markdown
# Compliance matrix {.appendix}
```

LaTeX numbers subsequent sections A, B, C and lists them in the table
of contents. Write the heading without its own letter.

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
