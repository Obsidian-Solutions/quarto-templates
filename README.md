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

## Documentation

- [docs/reference.md](docs/reference.md): the reference manual
  (front-matter fields, format matrix, brand, verification gates,
  GSCP values)
- [docs/decisions.md](docs/decisions.md): the architecture decisions
  and their rationale
- [CHANGELOG.md](CHANGELOG.md): the release history, generated from
  the commit history by `scripts/make-changelog.py`

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

Set the metadata in the front matter. The essential fields are
`title`, `author`, `date`, `reference`, `version`, and
`confidentiality`. Two fields carry legal and compliance weight:
`proprietor` (sole-trader trading-name disclosure, CA 2006 Part 41)
and `gscp` (optional Government Security Classifications
validation). The full field table is in
[docs/reference.md](docs/reference.md).

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

`scripts/check-pdfua.py` is the honest gate. It fails when a UA-2 render
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

The per-format capabilities are in [docs/reference.md](docs/reference.md).

## Examples

Each example file demonstrates one format from a single front
matter block:

| File | Format family | Shows |
|---|---|---|
| `examples/template.qmd` | PDF, HTML, DOCX, EPUB | The full document surface: cover, approval, revision history, citations, appendices, list of tables and figures |
| `examples/template-slides.qmd` | revealjs, beamer PDF, PPTX | A client deck with the classification banner |
| `examples/template-dashboard.qmd` | dashboard | A service-health dashboard with cards and a status table |

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

The identity is monochrome: a near-black primary (`#121212`, 16.8:1
on white), a grey secondary (`#484949`, AAA), and grey hairlines.
The palette table and the rebranding instructions are in
[docs/reference.md](docs/reference.md).

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

1. **Page-overflow gate.** Any `Overfull \hbox` or `\vbox` fails the
   render, so no document ships with content clipped at a margin.
2. **Controlled-language gate** (`scripts/check-ste.py`). Fails on
   the JSP 101 / ASD-STE100 hard violations. A document opts out with
   `ste: false`.
3. **PDF/UA-2 structure gate** (`scripts/check-pdfua.py`). Fires only
   for UA-2 renders and fails when the tagged structure tree lacks
   heading roles.

The full gate detail and the exempt-by-design list are in
[docs/reference.md](docs/reference.md).

## Optional GSCP classification mode

Set `gscp: true` in the front matter to validate the marking against
the UK Government Security Classifications Policy (GSCP v2.0). The
gate fails the render on obsolete levels (RESTRICTED, CONFIDENTIAL),
warns on SECRET and TOP SECRET, and accepts an OFFICIAL-SENSITIVE
reason after a colon. The accepted values are in
[docs/reference.md](docs/reference.md).

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
