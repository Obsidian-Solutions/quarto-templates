# Architecture Decisions

This file records the significant decisions about the template's
structure and standards posture. It follows the GDS Way convention
that a repository documents its own architecture decisions. Each
entry states the context, the decision, and the consequence. New
entries go at the top.

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

**Consequence.** Three source files, three render commands, nine
formats. Merging the families would guarantee content loss, so the
split is deliberate.

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
