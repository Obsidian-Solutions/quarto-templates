# Accessibility statement

This statement covers the example document site published from this
repository (https://obsidian-solutions.github.io/quarto-templates/).
It is a voluntary statement: Obsidian Solutions is a private business,
not a public sector body, so the Public Sector Bodies Accessibility
Regulations 2018 do not apply to it. We publish it because accessible
documents are the professional floor, and the statement keeps us
honest about the limits of the toolchain.

## Our commitment

- The HTML companion is the reading format. It targets WCAG 2.2 AA.
- Text contrast passes AAA: primary text 16.8:1 on white and 16.6:1
  on the dark background; secondary text 9.0:1 and 9.4:1.
- A visible focus ring (WCAG 2.4.7) and permanent link underlines
  mean colour is never the only cue.
- Images carry alt text. Figures and tables are labelled and
  cross-referenced, never described as "the figure above".
- The PDF is the archive copy (PDF/A-4f), published alongside the
  HTML. The PDF is not a substitute for the HTML.
- The Typst PDF (`template-typst.pdf`) is a fast-draft archive copy.
  It carries the same PDF/A-4f provenance as the LaTeX PDF and the
  house typography, but it is not tagged: Typst does not emit a
  structure tree in this template's configuration. It is published
  for download, not as the reading format. The HTML companion
  remains the accessible reading format.

## Known limitations

- **PDF/UA-2 heading roles.** The PDF/UA-2 option cannot yet tag
  section headings as H1-H6 (an upstream Quarto/KOMA limitation,
  documented in the README). A render that opts into PDF/UA-2 is
  gated by `tools/check-pdfua.py`, which fails the render when heading
  roles are missing, so no heading-less document ships as accessible.
  The default PDF/A-4f output is deliberately untagged to keep the
  table of contents clickable; the HTML companion carries the
  accessible structure.
- **Typst structure tree.** The Typst fast-draft PDF has no tagged
  structure tree and no alt-text hook for figures in this template's
  current configuration. Use the HTML companion for screen-reader
  access to the document content.
- **DOCX companion.** The client-editable DOCX carries the house
  style but is not accessibility-validated. Treat the DOCX as a
  working copy, not the accessible record.
- **Maths.** Tagged maths readable by all assistive technology is not
  reliably producible with the current LaTeX toolchain.

## Reporting problems

To report an accessibility problem with the example site or the
template, email security@obsidiansolutions.co.uk. We acknowledge
reports within five working days and aim to fix confirmed issues
within 30 days.

## Review

We review this statement whenever the template's rendering changes,
and at least once a year.
