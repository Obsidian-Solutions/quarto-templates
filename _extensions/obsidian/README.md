# Obsidian Solutions Quarto Extension

Controlled business documents in the Obsidian Solutions brand, from
one source file: PDF/A-4f with provenance, accessible HTML, editable
DOCX, revealjs decks, and dashboards.

`quarto add Obsidian-Solutions/quarto-templates` installs this
directory into `_extensions/Obsidian-Solutions/obsidian/`. The
formats are `obsidian-pdf`, `obsidian-html`, `obsidian-docx`,
`obsidian-pptx`, `obsidian-revealjs`, `obsidian-beamer`,
`obsidian-dashboard`, and `obsidian-epub`.

## Front matter

Populate the metadata surface. The fields feed the cover, the running
header, the footer, and the PDF metadata.

| Field | Purpose |
|---|---|
| title, subtitle, author, date | Document identity |
| reference, version | Document control (JSP 945 style) |
| confidentiality | Marking, shown top and bottom of every page |
| classification | accepted as an alias for `confidentiality` (the field name used by GSCP-style templates) |
| doc-type, edition, supersedes, review-date | Cover lines; an overdue review date warns on render |
| short-title | Running header title |
| keywords, abstract, lang | Search and summary; lang defaults to en-GB |
| watermark, draft | Diagonal watermark; `draft: true` adds a DRAFT status |
| approver, approver-role, approval-date | Approval page after the cover |
| changes | Revision history, newest first (JSP 945) |
| attach | Files embedded in the PDF/A-4f archive (provenance) |
| sections-new-page | Start each numbered section on a fresh page |
| proprietor | Sole-trader trading-name disclosure (CA 2006 Part 41), shown in the footer |
| gscp | `true` validates the marking against the Government Security Classifications (GSCP v2.0). Default off |
| ste | `false` opts a document out of the controlled-language gate. Default on |

## Outputs

- **PDF**: PDF/A-4f archive, validated with veraPDF when installed.
  Roman front matter, arabic body, numbered sections, clickable
  contents, classification in header and footer, watermark, approval
  page, embedded source and control manifest.
- **HTML**: accessible companion, light and dark themes, WCAG AAA
  contrast, classification banner.
- **DOCX / PPTX**: editable companions carrying the classification
  marking.
- **Revealjs / beamer / dashboard**: presentations and live-data
  products. The revealjs and beamer decks share the 16:9 format and
  the classification footline; the dashboard is a live-data product.
- **Epub**: e-reader distribution, with the classification banner and
  the brand mark as the cover image.

## Verification gates

`render.sh` in the source repository runs the gates. The installed
extension enforces the optional mode that ships inside the
extension: `gscp: true` fails the render on obsolete or invalid
classifications. The controlled-language gate (`ste`) is the example
project's build tooling (`tools/check-ste.py` in the source
repository), not part of the installed extension. `quarto add`
copies only this directory, so a user who wants the gate copies the
script with the example project.

## Licence

MIT. Third-party components inside this directory (the CSL style, the
reference documents) carry their own licences; see NOTICE.
