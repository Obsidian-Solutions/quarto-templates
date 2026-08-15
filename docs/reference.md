# Reference

This file is the reference manual for the Obsidian Solutions Quarto
template. The README teaches and explains; this file describes the
machinery. Each section is the full detail for one part of the
template.

## Front matter

Populate the metadata surface. The fields feed the cover, the
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
| gscp | `true` enables the optional Government Security Classifications validation (see the GSCP section below). Default off |
| ste | `false` opts a document out of the controlled-language gate, for example to quote external material verbatim. Default on |

`attach` entries must exist in the working directory at render time.
`render.sh` generates `manifest.json` with the document, baseline and
render date; the example attaches it alongside the source.

Set `baseline` manually only if you render without `render.sh`.

## Themed title page

The `obsidian-pdf` format offers an opt-in themed cover page. When the
`titlepage` key is absent, the standard monochrome cover renders and
existing documents are unaffected. Set the key to switch:

| Value | Effect |
|---|---|
| `titlepage: plain` | default business cover: classification, logo, title, author, date, identity line |
| `titlepage: formal` | centred, heavier title; report cover |
| `titlepage: classic-lined` | rules above and below the title |
| `titlepage: colorbox` | title in a filled box |
| `titlepage: academic` | journal-style author and affiliation machinery |
| `titlepage: bg-image` | background image behind the content (requires `titlepage-bg-image`; the theme errors without one) |
| `titlepage: banded` | full-page maroon band, gold rule, white title block |
| `titlepage: banded-slate` | full-page slate band, yellow rule, white title block |
| `titlepage: true` | same as `plain` |
| `titlepage: false` | no cover page at all |
| `titlepage: <file.tex>` | include a custom LaTeX cover file |

The mechanism is a port of the `quarto_titlepages` architecture: the
Lua filter (`filters/titlepage.lua`) validates the keys, fills theme
defaults, and records which style variant is active; the TeX partials
(`partials/titlepage*.tex`) turn the values into a layout.

Tune the chosen theme with a `titlepage-theme:` block:

| Key | Purpose |
|---|---|
| `titlepage-theme.elements` | ordered list of blocks: `headerblock`, `logoblock`, `titleblock`, `authorblock`, `affiliationblock`, `dateblock`, `footerblock`, `vfill` |
| `titlepage-theme.page-align` | `left`, `center`, `right` |
| `titlepage-theme.title-style` | `plain`, `colorbox`, `doublelinewide`, `doublelinetight` |
| `titlepage-theme.title-fontsize` / `title-fontstyle` | title size and style list (for example `[huge, bfseries]`) |
| `titlepage-theme.title-color` | title colour (defaults to the brand near-black) |
| `titlepage-theme.subtitle-*` | subtitle size, style, colour, spacing |
| `titlepage-theme.author-style` | `plain`, `plain-with-and`, `superscript`, `superscript-with-and`, `two-column`, `author-address` |
| `titlepage-theme.author-fontsize` / `author-fontstyle` / `author-color` | author rendering |
| `titlepage-theme.affiliation-style` | `numbered-list`, `numbered-list-with-correspondence` |
| `titlepage-theme.header-*` / `footer-*` / `date-*` | those blocks' size, style, colour, spacing |
| `titlepage-theme.logo-size` | logo width |
| `titlepage-theme.page-color` / `page-html-color` | whole-page background colour |
| `titlepage-theme.classification-color` | classification marking colour (the banded themes set white) |
| `titlepage-theme.band-rule-color` / `band-rule-width` / `band-rule-space` | the banded themes' contrast rule |
| `titlepage-theme.bg-image-size` / `bg-image-location` | background image size and corner (`ULCorner`, `URCorner`, `LLCorner`, `LRCorner`, `Center`) |

Direct keys sit alongside `titlepage`:

| Key | Purpose |
|---|---|
| `titlepage-logo` | logo image; defaults to `obsidian-logo.png`, `false` omits it |
| `titlepage-header` | text above the title block |
| `titlepage-footer` | text below the content |
| `titlepage-bg-image` | background image file; the `bg-image` theme errors without it. The extension bundles a neutral corner motif (`assets/corner-bg.png`); set `titlepage-bg-image: corner-bg.png` (format-resources flatten to the render root) |
| `titlepage-geometry` | page geometry for the cover only (for example `[top=5cm, bottom=2.6cm]`) |

Every themed page keeps the classification marking top-right and the
identity line (reference, edition, review) at the bottom, so the cover
stays traceable and marked like every other page.

## Formats

The template contributes nine formats. Each example source file
declares its full format family in the front matter, so one render
command per file produces the whole family with no content loss.

| Format | Output | Notes |
|---|---|---|
| `obsidian-pdf` | PDF/A-4f default, any standard selectable | branded cover, approval page, abstract, revision history, contents each on their own page, roman front matter, arabic body, numbered sections, classification in header and footer, baseline and page numbers, widow and orphan control, optional watermark, per-document PDF standard |
| `obsidian-html` | HTML | accessible companion, light and dark themes, WCAG AAA contrast |
| `obsidian-docx` | DOCX | client-editable companion, house style, no LaTeX-only front matter |
| `obsidian-epub` | EPUB | e-reader distribution, classification banner, brand cover image |
| `obsidian-revealjs` | HTML deck | house palette and typography, classification banner, `##` for slides |
| `obsidian-beamer` | PDF deck | 16:9, classification footline on every slide including the title |
| `obsidian-pptx` | PPTX | editable deck, classification marking on every slide |
| `obsidian-dashboard` | HTML | live-data dashboard, html theme, classification filter only |
| `obsidian-typst` | PDF/A-4f via Typst | fast-draft format, house palette and fonts, classification in running header, identity line, plain and banded covers. `pdf-standard` passes through to Typst (PDF/A-4f and PDF/UA verified); `render.sh` attaches the source and manifest with the AFRelationship + MIME keys PDF/A-4f requires, so the Typst archive carries the same provenance as the LaTeX PDF |

## Invoice documents

An invoice is not a separate format. It is an `obsidian-pdf` document
with the `invoice.lua` filter, which the pdf format contributes. Any
`obsidian-pdf` document that carries an `invoice:` metadata block
renders the invoice furniture at a marker Div:

```markdown
::: {.obsidian-invoice}
:::
```

The filter expands the structured `invoice:` metadata into the body at
the marker: a client block, a line-item table, totals, and a
provider-agnostic payment block. Everything else the author writes
stays untouched, so notes and sign-off sit around the invoice data.

The payment block renders from the `payment:` section. Supported
providers:

- `stripe`, `paypal`, `generic`: one "Pay now" line with the link
- `bank-transfer`: a bank details block (bank, sort code, account,
  account name, payment reference)
- absent: payment terms only

`discount` and `tax` metadata adjust the total. Totals are computed in
pence to avoid float drift. All amounts are pounds sterling (GBP).

The `proprietor:` front-matter field is the sole-trader trading-name
disclosure required by the Companies Act 2006, Part 41. A business
trading under a name other than the owner's true name must show the
owner's name and a service address on invoices and other business
documents. Set it to "Name, Address":

```yaml
proprietor: "John Smith, 1 Example Road, Exeter EX1 1AA"
```

The invoice example uses a placeholder value. Replace it with the real
name and service address. Limited companies do not use this field; they
show a registered office and company number instead.

## Invoice fields

The `invoice:` block carries the structured data. Example:

```yaml
invoice:
  sender:
    name: "Obsidian Solutions"
    address: |
      [business address]
    contact: "[email address] | [phone number]"
  number: "2026-008"
  date: "2026-08-15"
  due-date: "2026-08-29"   # optional, shown in the client block
  client:
    name: "Acme Ltd"
    address: |
      1 High Street
      Exeter EX1 1AA
  items:
    - description: "Server care retainer, August 2026"
      quantity: 1
      unit-price: "300.00"
  discount: "25.00"     # optional, subtracts from the subtotal
  tax: "0.00"           # optional adjustment (a negative value adds)
  payment:
    terms: "Due within 14 days"
    provider: "stripe"
    link: "https://buy.stripe.com/..."
```

| Field | Purpose |
|---|---|
| `sender.name` | Business name in the letterhead, defaults to the document `author` |
| `sender.address` | Business address in the letterhead, one line per line break |
| `sender.contact` | Contact line in the letterhead, for example email and phone |
| `number` | Invoice number, shown right-aligned in the header row |
| `date` | Invoice date, shown right-aligned in the header row |
| `due-date` | Payment due date, shown right-aligned in the header row; optional |
| `client.name` | Client organisation, shown in the Bill to block |
| `client.address` | Client address, one line per line break |
| `items[].description` | Line item description |
| `items[].quantity` | Quantity, default 1 |
| `items[].unit-price` | Unit price as a money string (for example `"300.00"` or `"£300.00"`) |
| `discount` | Money string subtracted from the subtotal |
| `tax` | Money string subtracted from the subtotal (a negative value adds) |
| `payment.terms` | Payment terms line, for example "Due within 14 days" |
| `payment.provider` | `stripe`, `paypal`, `generic`, or `bank-transfer` |
| `payment.link` | Payment link, rendered as a "Pay now" line for the link-based providers |
| `payment.details` | Bank details block, used only by `bank-transfer` |

The bank-transfer provider renders these details fields, then a
standing anti-fraud note: the invoice states that bank details are
never changed by email, and that the client should verify such a
request by phone on a known number. This follows NCA and Stop! Think
Fraud guidance on invoice fraud.

The bank-transfer provider renders these details fields:

```yaml
payment:
  terms: "Due within 14 days of the invoice date"
  provider: "bank-transfer"
  details:
    bank: "Example Bank"
    sort-code: "00-00-00"
    account: "00000000"
    name: "Obsidian Solutions"
    reference: "INV-2026-008"
```

An invoice is a commercial document. Set `titlepage: false`, `toc:
false`, `lof: false`, and `lot: false` in the front matter so the
document stays one page with no cover or front-matter lists.

See [examples/template-invoice.qmd](../examples/template-invoice.qmd)
for the full field surface.

Quarto can also emit plain formats (markdown, LaTeX, ODT, Typst,
ipynb) with `quarto render ... --to <format>`. Those carry no
Obsidian Solutions branding: the filters, partials, and themes are
format-specific, and a format with no `obsidian-*` equivalent renders
with Quarto's defaults.

## PDF standards

The PDF format defaults to PDF/A-4f, but that is a default, not a
limit. Every document selects its own standard in the front matter:

```yaml
format:
  obsidian-pdf:
    pdf-standard: [a-2u]     # or any value from the matrix below
```

Quarto 1.10 validates each render against the requested standard with
veraPDF (`quarto install verapdf`). The full matrix available to the
LuaLaTeX engine:

| Category | Values | Notes |
|---|---|---|
| PDF versions | `1.4`, `1.5`, `1.6`, `1.7`, `2.0` | plain PDF, no archival guarantees |
| PDF/A (archival) | `a-1b`, `a-2a`, `a-2b`, `a-2u`, `a-3a`, `a-3b`, `a-3u`, `a-4`, `a-4f` | a-4f is the default and the current ISO 19005 part |
| PDF/UA (accessibility) | `ua-2` | accessible tagging on top of an archival level, for example `[a-2b, ua-2]` |
| PDF/X (print exchange) | `x-4`, `x-4p`, `x-5g`, `x-5n`, `x-5pg`, `x-6`, `x-6n`, `x-6p` | ISO 15930, for commercial print handoff |

Every standard runs the same branded machinery: cover, title page,
classification marking, baseline, and gates. Two standards have known
limits that apply to this template's assets, verified against a real
render:

- **a-1b** (PDF/A-1, ISO 19005-1): forbids embedded files and soft
  masks. Drop the `attach:` provenance field, and use a flattened
  brand logo without alpha transparency. PDF/A-2 and later allow both,
  so `a-2u` is the lowest archival level that keeps provenance.
- **ua-2** (PDF/UA, ISO 14289-2): the upstream LaTeX tagging still
  leaves gaps (DisplayDocTitle, Tabs, structure destinations). The
  accessibility statement documents the current state; the
  `tools/check-pdfua.py` gate fails honestly when a ua-2 render lacks
  heading roles. The default a-4f stays untagged so the table of
  contents remains clickable.

The PDF/UA structure gate in `render.sh` reads the document's own
front matter, so a document that opts into ua-2 is checked even
though the extension default is a-4f.

## Brand

The palette is monochrome, drawn from the website brand colour with a
functional grey scale for text, secondary and hairline tones:

| Role | Hex | Contrast on white |
|---|---|---|
| Primary text | `#121212` | 16.8:1 |
| Secondary text | `#484949` | 9.0:1 (passes AAA) |
| Rules and hairlines | `#cecece` | decorative |

The palette lives in one place: `_extensions/obsidian/brand.yml` holds
every colour, the type scale and the spacing scale. `tools/tokens.py`
generates the per-engine token files from it:

| Generated file | Consumer | Contents |
|---|---|---|
| `tokens.tex` | PDF preamble (`\input{tokens.tex}`) | `\definecolor` for every token plus legacy aliases |
| `tokens.scss` | HTML themes and documents | `$token-*`, `$type-*`, `$space-*` variables |

Regenerate after any palette change with `python3 tools/tokens.py`,
and verify the theme still agrees with `tools/tokens.py --check` (a
drift guard: the HTML light theme keeps literal values because Quarto
evaluates the defaults section before file imports, so the check mode
fails CI when the two disagree).

The neutral palette in `brand.yml` adds named accent swatches (plum,
maroon, slate, blue, gold, ...). They are opt-in: a document sets one
as a `titlepage-theme` colour or an HTML accent, and the house look is
unchanged when none is used.

## HTML components

The HTML companion carries five opt-in components (`_components.scss`,
imported by both the light and dark themes). They use the house
tokens, so they adapt to the active theme automatically.

| Component | Use | Markup |
|---|---|---|
| Masthead | tinted band behind the title | Quarto's native `title-block-banner: true`, or a `{.obsidian-masthead}` block |
| Summary list | key/value table from a definition list | automatic: `filters/summary-list.lua` wraps every definition list |
| Inset text | guidance box with a thick left rule | `::: {.obsidian-inset-text}` |
| Phase banner | status strip (draft, review, live) | `::: {.obsidian-phase-banner}` with a `{.obsidian-phase-banner__label}` span |
| Organisation logo | name with a brand bar | `::: {.obsidian-org-logo}` |

Example usage:

```markdown
::: {.obsidian-phase-banner}
**STATUS** Draft for internal review
:::

Reference
: OS-DOC-003

Version
: 2.0.0

::: {.obsidian-inset-text}
Do not distribute without the owner's consent.
:::
```

The summary list is the only automatic component: a definition list
becomes a key/value table with the keys in a bold left column. A
definition list used for another purpose opts out with
`::: {.obsidian-summary-list false="true"}`.

## Verification gates

`render.sh` runs the gates on every render, and the CI runs them on
the example documents. The gates are engine-aware: the LaTeX engine
runs the page-overflow and cross-reference gates from its log, the
Typst engine attaches provenance instead, and the shared gates run
for both.

1. **Page-overflow gate** (LaTeX). Any `Overfull \hbox` or `\vbox`
   in the LaTeX log fails the render, so no document ships with
   content clipped at a margin.
2. **Cross-reference gate** (LaTeX). A broken `\ref` or `\cite`
   prints `??` and fails the render, so no document ships with dead
   links or missing bibliography entries.
3. **Provenance gate** (Typst). `tools/attach-provenance.py` embeds
   the source and manifest with the `AFRelationship` and MIME keys
   PDF/A-4f requires; a Typst archive without embedded provenance is
   a false green.
4. **Font-embedding gate** (`tools/check-pdfua.py`'s sibling in the
   pipeline; runs `pdffonts`). Every font must be embedded with a
   ToUnicode map, which PDF/A requires for text extraction.
5. **Controlled-language gate** (`tools/check-ste.py`). Fails on
   hard violations of the JSP 101 / ASD-STE100 word lists: banned
   words, marketing adjectives, phrasal verbs, modal hedges,
   contractions, American spellings, and em dashes. Long sentences,
   passive voice and semicolons are warnings. Blockquotes are exempt
   (verbatim quoted material), and a document opts out with
   `ste: false` in its front matter.
6. **PDF/UA-2 structure gate** (`tools/check-pdfua.py`). Fires only
   for UA-2 renders and fails when the tagged structure tree lacks
   heading roles.

Each gate fails the render if its tool is missing, so a clean run is
never a false green. `GATE_SKIP` names gates to disable deliberately
(comma-separated: `provenance,pdffonts,pdfua,ste,pptxlogo`), for
environments that render without the full toolchain. The deck
branding step (`tools/attach-pptx-logo.py`) is guarded the same way
under the `pptxlogo` name.

Exempt-by-design from the language gate, so the gate measures
documents and not machinery:

- `tools/check-ste.py` itself: the embedded word list is the source
  the gate checks against.
- `theme*.scss` and `epub.css`: CSS colour tokens and property names
  are not prose.
- Fixed identifiers: `SPDX-License-Identifier`, the `LICENSE`
  filename, `SIL Open Font License`, and the licence URLs in the
  NOTICE files. They are standard strings from their licences.
- `CODE_OF_CONDUCT.md` and `SECURITY.md`: supplied by the
  organisation's repository defaults, not maintained in this
  repository.
- `_extensions/obsidian/NOTICE`: the remaining hits are the fixed
  identifiers above and table cells that carry licence URLs.

The supply-chain record is `sbom.spdx.json`, generated by
`tools/make-sbom.py` (stdlib only) and checked for freshness in CI,
so the committed SBOM cannot go stale.

## Optional GSCP classification mode

Set `gscp: true` in the front matter to validate the marking against
the UK Government Security Classifications Policy (GSCP v2.0). The
gate (`filters/classification-gate.lua`):

- accepts `confidentiality` or `classification` (an accepted alias)
- defaults to OFFICIAL when no marking is set
- fails the render on obsolete levels (RESTRICTED, CONFIDENTIAL) or
  values outside the GSCP set
- accepts an OFFICIAL-SENSITIVE reason after a colon, for example
  "OFFICIAL-SENSITIVE: COMMERCIAL"
- warns when SECRET or TOP SECRET is used, because their handling
  requirements are outside what a template can enforce

This mode is for documents that must meet the Government Security
Classifications. The default posture is commercial (free-text
marking), per the standards posture in the README.

## Controlled-language gate

The `ste` front-matter option controls the controlled-language gate
(JSP 101 / ASD-STE100). The gate fails the render on banned words,
marketing adjectives, phrasal verbs, modal hedges, contractions,
American spellings, and em dashes. Blockquotes are exempt: they
carry verbatim quoted material, which the author cannot rewrite.

The gate is the example project's build tooling. `quarto add`
installs only the `_extensions/` directory, so an installed extension
does not carry the script. A user who wants the gate copies
`tools/check-ste.py` with the example project.
