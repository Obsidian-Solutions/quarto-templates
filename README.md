# Quarto Docs Template

A distributable Quarto template for Obsidian Solutions documents. It
produces a clean, professional PDF for print and offline use, plus an
HTML version for reading, from one source file.

The template follows the document standards in the standards library
(UK PDF document standards, LaTeX/Pandoc/Quarto production) and the
professional floor they set: full metadata surface, pagination
control, accessible companion output, and a traceable baseline. The
style is neutral and professional. It does not mimic any government
identity.

## Requirements

- Quarto 1.3 or later
- A LaTeX engine (lualatex)
- Liberation fonts

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
footer, and the PDF metadata.

| Field | Purpose |
|---|---|
| title | Document title |
| subtitle | Subtitle |
| author | Author or organisation |
| date | Publication date |
| reference | Document reference number |
| version | Document version |
| confidentiality | Marking such as "Private and Confidential" |
| short-title | Running header text |
| keywords | Search terms |
| abstract | Summary |
| lang | Language, set to en-GB |

Set `baseline` manually only if you render without `render.sh`.

## Output

- **PDF**: cover page, contents, numbered sections, running header
  and footer with baseline and page numbers, widow and orphan
  control.
- **HTML**: the accessible companion for reading, per the HTML-first
  rule.

For archival copies, enable the PDF/A option in `_format.yml` and
validate with veraPDF. The default output is not PDF/A.

## Fonts

Liberation Serif and Sans are used. GDS Transport is proprietary and
limited to gov.uk domains, and no public MOD typeface exists, so
Liberation is the professional free fallback.

## Licence

MIT. See [LICENSE](LICENSE).
