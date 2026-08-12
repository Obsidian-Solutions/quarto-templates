# Quarto Templates

A distributable set of Quarto templates for Obsidian Solutions. One
source file produces a clean, professional PDF for print and offline
use, an HTML version for reading, a DOCX for client editing, a
revealjs deck for presenting, and a dashboard for live figures.

The template follows the document standards in the standards library
(UK PDF document standards, LaTeX/Pandoc/Quarto production,
GOV.UK and MOD design-review floors) and the professional conventions
those systems establish: full metadata surface, pagination control,
a classification marking on every page, WCAG-checked contrast, and a
traceable baseline. The identity is our own monochrome brand: a
near-black primary drawn from the website brand colour, with greys
for secondary text and rules. It does not mimic any government
identity.

## Standards posture

Obsidian Solutions is a civilian sole-trader business. We are not
endorsed by the MOD and hold no government endorsement. We adopt the
defence and government standards in this library voluntarily, because
they are the best available floor for controlled, professional
documents, and we comply with the civilian law that actually binds us
(trading-name disclosure, copyright, accessibility, data protection)
in the same codebase. Where a standard is for government use only,
for example the Government Security Classifications (GSCP), it is an
optional mode in this template, not the default. UK law is vast and
complex; the option exists so that we, or anyone using the template,
can meet a standard when they wish or need to, without the template
imposing it on everyone. The default posture is commercial: a
free-text confidentiality marking such as "Commercial in Confidence",
with the GSCP validation available under `gscp: true`.

## Requirements

- Quarto 1.9 or later
- A LaTeX engine (lualatex) on TeX Live 2023 or later
- TeX Gyre Pagella, Montserrat and Liberation Mono fonts
- Python 3 (for the validation gates in `scripts/`)
- Optionally `quarto install verapdf` for PDF/A validation

## Use as a template

1. Copy this repository, or clone it and remove the examples.
2. Edit `examples/template.qmd`: front matter first, then content.
3. Render with `./render.sh examples/template.qmd`.

The script stamps the baseline (commit and date) into the cover and
footer automatically. Rendered output goes to `_output/` (the project
`output-dir`), keeping the working directory free of generated files;
the LaTeX build log is moved there too after the render gates read
it.

## Use as a Quarto extension

Add the format to any project:

```
quarto add Obsidian-Solutions/quarto-templates
```

Then set in the document front matter:

```
format: obsidian-pdf
```

The extension installs as a tracked copy under
`_extensions/Obsidian-Solutions/obsidian/`. Pull template updates
with:

```
quarto update Obsidian-Solutions/quarto-templates
```

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
| gscp | `true` enables the optional Government Security Classifications validation (see below). Default off |
| ste | `false` opts a document out of the controlled-language gate, for example to quote external material verbatim. Default on |

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

One source file per artefact type, each declaring its full format
family in the front matter. One render command per file produces the
whole family with no content loss between formats: the document
renders to PDF, HTML, DOCX, and EPUB from the same prose; the deck
renders to revealjs, beamer PDF, and PPTX from the same slides. The
three source files exist because a document, a deck, and a dashboard
are different artefacts: a slide is a summary, not a paragraph, and
merging the families would guarantee loss, not avoid it.

- **PDF**: branded cover page, optional approval page, abstract,
  revision history, and contents each on their own page,
  roman-numbered front matter and arabic body, numbered sections,
  running header and footer with the classification marking, baseline
  and page numbers, widow and orphan control, optional diagonal
  watermark.
- **HTML**: the accessible companion for reading, per the HTML-first
  rule. It follows the reader's system preference between the light
  and dark themes (`theme-dark.scss`), both of which pass WCAG AAA
  contrast.
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
- **Beamer** (`obsidian-beamer`): PDF presentations, for clients or
  channels that need slides as a PDF. Same 16:9 format and
  classification footline as the revealjs deck: the marking and the
  frame number sit on every slide, including the title slide. Use the
  same `##` slide structure.
- **PPTX** (`obsidian-pptx`): the client-editable deck, carrying the
  classification marking on every slide via the reference-file footer.
- **Epub** (`obsidian-epub`): e-reader distribution of the document.
  The classification banner and the controlled-language gate apply.
  The brand mark becomes the cover image.
- **Dashboard** (`obsidian-dashboard`): client-facing dashboards for
  live data. Uses the html theme. Only the classification filter
  applies, since review warnings are for documents.

Quarto can also emit plain formats (markdown, LaTeX, ODT, Typst,
ipynb) with `quarto render ... --to <format>`. Those carry no
Obsidian Solutions branding: the filters, partials, and themes above
are format-specific, and a format with no `obsidian-*` equivalent
renders with Quarto's defaults.

## Examples

Each example file demonstrates one format from a single front
matter block:

| File | Format | Shows |
|---|---|---|
| `examples/template.qmd` | `obsidian-pdf`, `obsidian-html`, `obsidian-docx` | The full document surface: cover, approval, revision history, citations, appendices, list of tables and figures |
| `examples/template-slides.qmd` | `obsidian-revealjs` | A client deck with the classification banner |
| `examples/template-dashboard.qmd` | `obsidian-dashboard` | A service-health dashboard with cards and a status table |

Render one file per family:

```bash
quarto render examples/template.qmd        # PDF + HTML + DOCX + EPUB
quarto render examples/template-slides.qmd # revealjs + beamer PDF + PPTX
quarto render examples/template-dashboard.qmd # dashboard
```

The examples are published to GitHub Pages from `main` in every
format the template produces (PDF, DOCX, HTML, revealjs slides, PPTX,
dashboard):

https://obsidian-solutions.github.io/quarto-templates/

They are sanitised: the demos carry no personal or internal detail.

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
fallbacks. Montserrat is downloaded from a pinned upstream commit
with a SHA-256 check on every download (`scripts/install-fonts.sh`),
so a changed or tampered font file fails the render loudly. The
licences of every component are recorded in [NOTICE](NOTICE).

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
3. **PDF/UA-2 structure gate** (`scripts/check-ua.py`). Fires only
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
marking), per the standards posture above.

## Air-gapped use

Document rendering is fully offline: every figure is a static asset,
no diagram tool (Mermaid, PlantUML or similar) spins up a headless
browser or calls a web service at build time, and no compute engine
runs at render. The only network access in the whole pipeline is a
one-time toolchain install (Quarto, a TeX distribution, the fonts in
`scripts/install-fonts.sh`, and optionally veraPDF). Install those
once on an online machine and the same tree renders identically on
an air-gapped one; the font and action pins make the offline build
reproducible.

## Licence

MIT. See [LICENSE](LICENSE).

Third-party components (the bundled CSL style, the reference
documents, and the fonts) carry their own licences. See
[NOTICE](NOTICE) for the full record and obligations.
