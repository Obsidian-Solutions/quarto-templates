# Architecture Decisions

This file records the significant decisions about the template's
structure and standards posture. It follows the GDS Way convention
that a repository documents its own architecture decisions. Each
entry states the context, the decision, and the consequence. New
entries go at the top.

## Themed title page as an opt-in system

**Context.** The fixed monochrome cover could not be restyled per
document without hand-editing the partial. The quarto_titlepages
extension proved the architecture (YAML keys drive a Lua filter,
which fills defaults and records style codes; TeX partials turn them
into a layout), but its defaults were journal-grade: Latin Modern
fonts, no colour control, placeholder logos, an unstyled table of
contents.

**Decision.** Port the quarto_titlepages architecture into the
extension as an opt-in `titlepage:` key with six themes (plain,
formal, classic-lined, colorbox, academic, bg-image) plus custom TeX
cover files and `titlepage: false`. Fix the port: house fonts,
house palette via per-element colour keys, a single configurable
logo, a date block, and the classification marking kept top-right on
every themed page. The key absent renders the standard cover, so
existing documents are unchanged.

**Consequence.** A document chooses its cover from YAML without
touching TeX. The themed page stays traceable (classification and
identity line) because those are emitted by the partial, not the
theme. The upstream flaws are fixed in the port, not inherited.

## Canonical design tokens

**Context.** The palette was repeated in three places: the LaTeX
`\definecolor` block, the HTML light theme, and the HTML dark theme.
A rebrand meant finding every hex value by hand, and the three
copies could drift.

**Decision.** `brand.yml` is the single source of truth for colour,
type, and spacing. `tools/tokens.py` (stdlib, no YAML dependency)
generates `tokens.tex` for LaTeX and `tokens.scss` for the HTML
themes. The HTML light theme keeps literal values because Quarto
evaluates the defaults section before file imports, so a `--check`
mode fails CI when the theme drifts from the source. The neutral
accent swatches use plain colour names with no provenance.

**Consequence.** A rebrand is one file plus a generator run. The
drift guard makes the split (LaTeX generated, SCSS literal) safe:
the check, not import resolution, keeps them honest. No external
design-system provenance appears anywhere in the design layer.

## HTML components as a neutral layer

**Context.** The quarto-govuk component set proved the pattern for
document-page furniture (masthead, metadata box, inset text, status
strip, organisation bar), but it was tied to another organisation's
identity and class names.

**Decision.** Port the component set onto the house tokens as one
shared `_components.scss` serving both light and dark themes, with
neutral `obsidian-*` class names and no external identity. The
summary list is the only automatic component (a Lua filter maps
definition lists to the key/value table); the rest are opt-in via
container classes.

**Consequence.** Documents get business-document furniture from the
house design system. The class names are the brand's own, so no
dependency on or attribution to any external identity layer.

## Per-document PDF standard, not a template lock

**Context.** The PDF format defaulted to PDF/A-4f with no documented
way to choose another standard. Quarto 1.10 supports the full
LuaLaTeX matrix: PDF versions 1.4-2.0, PDF/A a-1b through a-4f,
PDF/UA ua-2, and PDF/X x-4 through x-6p.

**Decision.** Keep a-4f as the default but make it a per-document
choice: every document overrides `pdf-standard` in its own front
matter. `render.sh`'s PDF/UA gate reads the document's front matter,
not the extension default, so a document opting into ua-2 is checked
even when the default is a-4f. The two known limits are documented:
a-1b forbids embedded files and soft masks (drop `attach:`, flatten
the logo), and ua-2 has upstream LaTeX tagging gaps.

**Consequence.** The template limits nothing. All six LuaLaTeX
standard categories render through the branded machinery and are
verified against the requested standard by veraPDF.

## Typst engine with PDF/A-4f provenance

**Context.** The Typst format could not emit PDF/A-4f or carry
provenance attachments (no embed primitive), so it was documented as
a fast draft with weaker guarantees than the LaTeX archive.

**Decision.** Three findings removed the limits. Quarto passes
`pdf-standard` through to Typst, so its render validates as PDF/A-4f.
`tools/attach-provenance.py` (pikepdf) embeds the source and
manifest after the render, writing the AFRelationship key and MIME
Subtype that PDF/A-4f clause 6.9 requires (qpdf's
`--add-attachment` writes neither). `render.sh` detects the engine
and runs the shared gates (STE, fonts, PDF/UA) plus the Typst
provenance gate, skipping only the LaTeX-log gates.

**Consequence.** The Typst format matches the LaTeX archive's
guarantees: PDF/A-4f validated, source and manifest embedded, fonts
with ToUnicode. One source file produces two archival renders from
two engines. The Typst engine also surfaced a real bug in the
committed format (the import alias broke the show rule) that the
render-verification at commit time had masked with a stale test
copy; the fresh-tree CI test now catches this class of error.

## Single maintainer and the two-person rule

**Context.** The NSA and CISA guidance "Defending CI/CD
Environments" (June 2023) and the NCSC secure development guidance
require a two-person rule for code updates and protected release
environments. The business has one maintainer, so two approvals are
impossible.

**Decision.** The controls that a single person can meet stand:
pull-request-only merges, signed commits, required status checks,
and branch protection on `main`. The release job runs in the
protected `release` environment, and the draft release is the human
review point before publish. A required reviewer for the release
environment is a settings click away when a second person joins.

**Consequence.** The two-person rule is documented as a deliberate
divergence, not a silent gap. Every other control in the guidance
applies.

## PDF/A-4f as the archival format

**Context.** The PDF output must survive long enough to be a
controlled record. ISO 19005-2 (PDF/A-2) and ISO 19005-4 (PDF/A-4)
both permit embedded files and tagged content.

**Decision.** Render PDF/A-4f (ISO 19005-4) by default, validated
with veraPDF in the render pipeline and in CI. PDF/A-4 uses the PDF
2.0 object model, which is the current ISO 32000-2 basis.

**Consequence.** The 4f conformance level keeps the embedded
provenance attachments (the source document and the control
manifest). veraPDF validates the result, so a non-conforming render
fails the pipeline loudly.

## Untagged default PDF, opt-in PDF/UA-2

**Context.** A tagged PDF structure tree is the foundation of PDF/UA
accessibility. Quarto and KOMA-Script emit a flat tree: headings
stay `Sect` or `Div` and never promote to `H1`-`H6` roles. veraPDF
does not catch this gap. Tagging the default render also breaks the
clickable table of contents.

**Decision.** The default PDF/A-4f render is deliberately untagged.
PDF/UA-2 is an opt-in extra (`pdf-standard: [a-4f, ua-2]`), checked
by `tools/check-pdfua.py`, which fails honestly on the missing
heading roles. The known limitation is documented in the README.

**Consequence.** The accessible HTML companion carries the screen
reader burden (the HTML-first rule). A UA-2 PDF never ships silently
with a flat structure: the checker or the documented gap stops it.

## GSCP as an optional mode

**Context.** The template serves civilian clients who do not need
Government Security Classifications, and documents that must meet
them. A hard GSCP gate would block the civilian path.

**Decision.** `gscp: true` in the front matter enables GSCP v2.0
validation. Without it, the default marking is the commercial
"Commercial in Confidence". The gate accepts `confidentiality` or
`classification`, defaults to OFFICIAL, and errors on obsolete
levels.

**Consequence.** One template serves both markets. The marking logic
is identical; only the validation strictness changes.

## One source file per artefact family

**Context.** A document, a presentation, and a dashboard are
different artefacts. A slide is a summary, not a paragraph. Rendering
a document as slides produces dense, unreadable slides, and rendering
slides as a document produces a stub.

**Decision.** Each artefact type has one source file in `examples/`.
Each source declares its full format family in the front matter, so
one render command produces every format in that family with no
content loss. The document family is PDF, HTML, DOCX, and EPUB. The
deck family is revealjs, beamer, and PPTX.

**Consequence.** One source file per artefact family, one render
command per file, nine formats across the families. Merging the
families would guarantee content loss, so the split is deliberate.

## The controlled-language gate is repo tooling

**Context.** The `ste` front-matter option promises a
controlled-language gate. `quarto add` installs only the
`_extensions/` directory, so a script in the repo's `tools/`
folder never reaches an installed user.

**Decision.** The gate (`tools/check-ste.py`) belongs to the
example project's build tooling. An installed extension enforces
only `gscp: true`. The extension README states this boundary.

**Consequence.** No overpromise. A user who wants the gate copies
the script with the example project.

## Montserrat pinned by commit and SHA-256

**Context.** The headings font is a supply-chain input. A changed or
tampered font file would alter every rendered document.

**Decision.** `tools/install-fonts.sh` downloads Montserrat from a
pinned upstream commit and verifies each TTF by SHA-256. A mismatch
fails the render.

**Consequence.** The font is reproducible. The TinyTeX distribution
in CI stays rolling (documented risk), but the fonts and the GitHub
Actions are pinned.
