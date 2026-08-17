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

## Local field verification

Set `verify: true` in the front matter to run a soft local check of the
document fields during the render (`filters/verify.lua`). The check
prints warnings to the render log and never fails the build, so a
document still renders when a field is wrong; the warning is the signal
to fix it before sending.

```yaml
---
title: "Invoice"
verify: true
---
```

The check covers the common fields and the invoice block:

- Required fields: title, author, date, and a reference in the house
  shape `OS-<TYPE>-<NNN>`
- Version in semantic versioning form, and a known confidentiality
  level (Open, Internal, Commercial in Confidence, Official,
  Official-Sensitive, Secret, Top Secret)
- The level set is the commercial levels plus the GSCP levels.
  Restricted and Confidential are obsolete under GSCP v2.0.
  Unclassified is not used
- Placeholder text anywhere: `[...]`, `<...>`, `TBD`, `xxx`, `lorem`,
  and blank values
- Addresses: UK postcode shape and placeholder markers
- Phone numbers: UK `+44` and `0` forms, checked in
  `invoice.sender.contact`, a line that may also carry an email
- Dates: ISO form, real calendar dates, and invoice ordering
  (supply date before invoice date before due date)
- The invoice block: sender and client present, items with positive
  quantity and a parseable unit price, subtotal recomputed within one
  penny, a known payment provider (stripe, paypal, generic,
  bank-transfer, none) with a payment link for stripe and paypal, and
  a coherent VAT status

The checks are deliberately conservative. A UK postcode shape check
does not prove the postcode exists; it catches the typing errors and
placeholder values that a template user is most likely to leave behind.

## Structured document blocks

The letter, memo, agenda, and brief templates carry their front-matter
metadata as structured blocks, and `filters/structured-fields.lua`
renders each block at a marker in the body. The marker is a Div with
the block's class; the filter replaces it with the rendered content.
A missing required field stops the render with a clear error, so a
document never ships with an empty recipient block or a heading table
that says nothing.

The letter uses two markers so the body prose sits between them:

```markdown
::: {.obsidian-letter}
:::

Body text of the letter.

::: {.obsidian-letter-closing}
:::
```

The memo, agenda, and brief use a single marker:

```markdown
::: {.obsidian-memo}
:::
```

The structured fields per block:

| Block | Required | Optional |
|---|---|---|
| `letter` | `address` (list) | `subject`, `opening`, `closing`, `cc` (list), `encl` (list), `ps`, `signature` |
| `memo` | `to` (list), `from`, `subject` | `cosig`, `cosig-title` |
| `agenda` | `meeting`, `date`, `time`, `location` | `chair`, `members` (list), `apologies` (list), `guests` (list) |
| `brief` | none | `series`, `issue`, `key-findings` (list), `cite-as`, `contact` (`name`, `email`, `phone`) |
| `decision` | `status` | `decision-makers` (list), `consulted` (list), `informed` (list) |
| `minutes` | `committee`, `date` | `time`, `location`, `chair`, `notetaker`, `present` (list), `absent` (list), `guests` (list), `actions` (list of `owner`, `due`, `text`) |
| `contract` | `party-a.name`, `party-b.name` | `party-a.address`, `party-b.address`, `term`, `governing-law` |
| `press-release` | none | `status`, `subheadline`, `dateline`, `contacts` (list) |
| `newsletter` | `name`, `issue` | `date` |
| `certificate` | `type`, `recipient` | `date` |
| `reading-list` | none | `scope` |
| `sop` | `number` | `approved-by`, `revision-date`, `author` |
| `after-action` | none | `facilitator`, `scenario` |
| `business-case` | none | `status`, `version`, `sponsor` |
| `project-charter` | none | `sponsor`, `team` |
| `dpia` | none | `activity`, `controller`, `dpo` |
| `audit-report` | `number` | `status`, `scope` |
| `incident-report` | none | `severity`, `duration`, `status` |
| `sow` | none | `client`, `period` |
| `fact-sheet` | none | `last-updated`, `developer`, `launch-date` |
| `requirements-spec` | none | `version`, `status`, `approval` |
| `technical-design` | none | `version`, `status`, `author` |
| `reference-letter` | none | `addressee`, `candidate`, `salutation` |
| `staff-report` | `to`, `from` | none |
| `release-notes` | `version` | `status` |
| `test-report` | none | `version`, `tester` |
| `rfp` | `issuer` | `deadline` |
| `sla` | `parties` | `term` |
| `exam-paper` | `course` | `duration`, `examiner` |
| `lab-report` | none | `course`, `student`, `partner` |
| `syllabus` | none | `code`, `term`, `instructor` |
| `essay` | none | `course`, `word-count` |
| `research-proposal` | none | `supervisor`, `duration` |
| `dissertation-proposal` | none | `degree`, `supervisor` |
| `literature-review` | none | `scope`, `reviewer` |
| `marking-rubric` | none | `course`, `marker` |
| `lecture-notes` | none | `course`, `date`, `speaker` |
| `legal-memo` | `to` | `from` |
| `board-minutes` | none | `company`, `date`, `location`, `chair` |
| `corporate-resolution` | none | `company`, `number` |
| `board-pack` | none | `meeting`, `period` |
| `strategy-paper` | none | `version`, `owner` |
| `policy-document` | none | `version`, `owner` |
| `procedure-document` | none | `version`, `owner` |
| `framework-document` | none | `version` |
| `terms-conditions` | none | `parties`, `term`, `governing-law` |
| `dpa` | none | `controller`, `processor` |
| `privacy-policy` | none | `controller`, `jurisdiction` |
| `non-compete` | none | `parties`, `term` |
| `cease-desist` | none | `recipient` |

For the letter the whole head (recipient block, date, reference,
subject, opening) is owned by LaTeX on PDF: the recipient block sits
left at the UK window-envelope position, the date aligns right at its
top line, and the reference and subject are field lines, not
headings. The closing block renders as closing, signature gap,
signature, then cc, enclosures, and P.S. The HTML and DOCX companions
keep the labelled block layout instead.

The memo head on PDF is a masthead chosen by the top-level
`memo-style` option (`centred`, `flush-left`, or `military`,
default `centred`). `centred` centres the MEMORANDUM title,
`flush-left` puts the title and date on one line, and `military`
uses the no-masthead memorandum form (MEMORANDUM FOR ... SUBJECT: ...).
All three print the To, From, Date, Subject, Reference, and
Co-signature lines as flush-left `Label: value` lines; no bordered
table is used on PDF.

The agenda head on PDF is a centred AGENDA masthead followed by the
Meeting, Date, Time, Location, Chair, and Reference lines as
flush-left `Label: value` lines; no bordered table is used on PDF.
The attendee, apology, and guest lists render in the body below the
head.

The policy brief head on PDF is a series/issue banner (series left,
issue and date right) with the key findings in a boxed block below
it. The citation and contact blocks render in the body. No bordered
table is used on PDF.

The decision record head on PDF is a centred DECISION RECORD masthead
with the decision title, status, date, decision makers, consulted,
informed, and reference lines as flush-left `Label: value` lines. The
context, drivers, options, outcome, and consequences sections render
in the body.

The meeting minutes head on PDF names the committee at the top with
the date, time, location, chair, notetaker, attendance, and reference
lines as flush-left `Label: value` lines. The present, absent, and
guest lists render in the body. A closing marker
(`.obsidian-minutes-actions`) placed at the end of the document
collects the `actions` list into an Action items section sorted by
due date.

The contract head on PDF centres the agreement title, then prints
"This Agreement is dated ... between:" with the two parties side by
side, then the term and governing law lines. The clause sections
render in the body.

The press release head on PDF centres the release status (default
FOR IMMEDIATE RELEASE), the headline, the subheadline, and the
dateline. The body carries the news, detail, and about sections. The
contact lines render at the end of the release.

The newsletter head on PDF is a centred masthead with the publication
name, then the issue and date on the line below, then a rule. The
body carries the items and the diary dates.

The certificate head on PDF is portrait: the issuer at the top, the
certificate type, the recipient name, and the date. The signature
block renders in the body.

The reading list head on PDF is a centred READING LIST masthead with
an optional scope line. The annotated entries render in the body.

The NDA and MOU heads on PDF carry the fixed masthead (NON-DISCLOSURE
AGREEMENT or MEMORANDUM OF UNDERSTANDING), the date-of-agreement
line, the two parties side by side, and the term and governing law
lines. Both reuse the `contract:` block for the parties; the clause
sections render in the body.

The SOP head on PDF is a centred STANDARD OPERATING PROCEDURE
masthead with the SOP number, title, date, approver, revision date,
author, and reference lines as flush-left `Label: value` lines. The
procedure steps render in the body.

The after-action report head on PDF is a centred AFTER-ACTION REPORT
masthead with the event, date, facilitator, scenario, and reference
lines. The ODR entries and action items render in the body.

The business case head on PDF is a centred BUSINESS CASE masthead
with the title, date, status, version, sponsor, and reference lines
as flush-left `Label: value` lines. The Five Case Model sections
render in the body.

The project charter head on PDF is a centred PROJECT CHARTER masthead
with the project, date, sponsor, team, and reference lines. The
objectives, success criteria, and milestones render in the body.

The DPIA head on PDF is a centred DATA PROTECTION IMPACT ASSESSMENT
masthead with the activity, controller, date, DPO, and reference
lines. The Article 35 assessment sections render in the body.

The audit report head on PDF is a centred AUDIT REPORT masthead with
the audit number, date, status, scope, and reference lines. The
findings, nonconformities, and corrective actions render in the body.

The incident report head on PDF is a centred INCIDENT REPORT masthead
with the incident, date, severity, duration, status, and reference
lines. The timeline, root cause, resolution, and prevention sections
render in the body.

The statement of work head on PDF is a centred STATEMENT OF WORK
masthead with the project, date, client, period, and reference lines.
The scope, deliverables, and milestones render in the body.

The fact sheet head on PDF is a centred FACT SHEET masthead with the
entity name, last updated, developer, launch date, and reference
lines. The key facts render as bullets in the body.

The requirements specification head on PDF is a centred
REQUIREMENTS SPECIFICATION masthead with the title, date, version,
status, approval, and reference lines. The IEEE 830 sections render
in the body.

The technical design document head on PDF is a centred TECHNICAL
DESIGN DOCUMENT masthead with the title, date, version, status,
author, and reference lines. The IEEE 1016 views and decisions
render in the body.

The reference letter head on PDF is a centred REFERENCE LETTER
masthead with the date, addressee, candidate, and reference lines,
then the salutation. The recommendation body renders below.

The staff report head on PDF is a centred STAFF REPORT masthead with
the To, From, date, subject, and reference lines. The situation,
options, and recommendation render in the body.

The release notes head on PDF is a centred RELEASE NOTES masthead
with the product, version, date, status, and reference lines. The
features, fixes, and upgrade notes render in the body.

The test report head on PDF is a centred TEST REPORT masthead with
the project, date, version, tester, and reference lines. The
strategy, results, and defects render in the body.

The request for proposal head on PDF is a centred REQUEST FOR
PROPOSAL masthead with the title, issuer, date, deadline, and
reference lines. The scope and evaluation criteria render in the body.

The service level agreement head on PDF is a centred SERVICE LEVEL
AGREEMENT masthead with the service, parties, date, term, and
reference lines. The service levels and credits render in the body.

The exam paper head on PDF is a centred EXAM PAPER masthead with the
course, date, duration, examiner, and reference lines. The questions
render in the body.

The laboratory report head on PDF is a centred LABORATORY REPORT
masthead with the experiment, course, date, student, partner, and
reference lines. The abstract, method, results, and discussion
render in the body.

The syllabus head on PDF is a centred SYLLABUS masthead with the
course, code, term, instructor, and reference lines. The schedule,
assessment, and policies render in the body.

The essay head on PDF is a centred ESSAY masthead with the title,
course, date, word count, and reference lines. The argument and
conclusion render in the body.

The research proposal head on PDF is a centred RESEARCH PROPOSAL
masthead with the proposal, date, supervisor, duration, and
reference lines. The objectives and methodology render in the body.

The dissertation proposal head on PDF is a centred DISSERTATION
PROPOSAL masthead with the dissertation, degree, date, supervisor,
and reference lines. The research plan renders in the body.

The literature review head on PDF is a centred LITERATURE REVIEW
masthead with the topic, scope, date, reviewer, and reference lines.
The thematic sections render in the body.

The marking rubric head on PDF is a centred MARKING RUBRIC masthead
with the assignment, course, date, marker, and reference lines. The
criteria table renders in the body.

The lecture notes head on PDF is a centred LECTURE NOTES masthead
with the lecture, course, date, speaker, and reference lines. The
notes render in the body.

The legal memo head on PDF is a centred LEGAL MEMO masthead with the
to, from, date, re, and reference lines as a TO/FROM/DATE/RE block.
The issue, facts, analysis, and conclusion render in the body.

The board minutes head on PDF is a centred BOARD MINUTES masthead
with the company, date, location, chair, and reference lines. The
resolutions and action items render in the body.

The corporate resolution head on PDF is a centred CORPORATE
RESOLUTION masthead with the company, resolution number, and date
lines. The resolved clauses render in the body.

The board pack head on PDF is a centred BOARD PACK masthead with the
meeting, date, and period lines. The reports and papers render in
the body.

The strategy paper head on PDF is a centred STRATEGY PAPER masthead
with the title, date, version, owner, and reference lines. The
context, options, and recommendation render in the body.

The policy document head on PDF is a centred POLICY DOCUMENT masthead
with the title, date, version, owner, and reference lines. The
policy statement and compliance sections render in the body.

The procedure document head on PDF is a centred PROCEDURE DOCUMENT
masthead with the title, date, version, owner, and reference lines.
The numbered steps render in the body.

The framework document head on PDF is a centred FRAMEWORK DOCUMENT
masthead with the title, date, version, and reference lines. The
principles and structure render in the body.

The terms and conditions head on PDF is a centred TERMS AND
CONDITIONS masthead with the parties, date, term, governing law, and
reference lines. The numbered clauses render in the body.

The data processing agreement head on PDF is a centred DATA
PROCESSING AGREEMENT masthead with the controller, processor, date,
and reference lines. The Article 28 obligations render in the body.

The privacy policy head on PDF is a centred PRIVACY POLICY masthead
with the controller, date, jurisdiction, and reference lines. The
data handling sections render in the body.

The non-compete agreement head on PDF is a centred NON-COMPETE
AGREEMENT masthead with the parties, date, term, and reference lines.
The restriction and enforcement sections render in the body.

The cease and desist head on PDF is a centred CEASE AND DESIST
masthead with the recipient, date, and reference lines. The demand
sections render in the body.

The examples (`template-letter.qmd`, `template-memo.qmd`,
`template-agenda.qmd`, `template-brief.qmd`, `template-decision.qmd`,
`template-minutes.qmd`, `template-contract.qmd`,
`template-press-release.qmd`, `template-newsletter.qmd`,
`template-certificate.qmd`, `template-reading-list.qmd`,
`template-nda.qmd`, `template-mou.qmd`, `template-sop.qmd`,
`template-after-action.qmd`, `template-business-case.qmd`,
`template-project-charter.qmd`, `template-dpia.qmd`,
`template-audit-report.qmd`, `template-incident-report.qmd`,
`template-sow.qmd`, `template-fact-sheet.qmd`,
`template-requirements-spec.qmd`, `template-technical-design.qmd`,
`template-reference-letter.qmd`, `template-staff-report.qmd`,
`template-release-notes.qmd`, `template-test-report.qmd`,
`template-rfp.qmd`, `template-sla.qmd`, `template-exam-paper.qmd`,
`template-lab-report.qmd`, `template-syllabus.qmd`,
`template-essay.qmd`, `template-research-proposal.qmd`,
`template-dissertation-proposal.qmd`, `template-literature-review.qmd`,
`template-marking-rubric.qmd`, `template-lecture-notes.qmd`,
`template-legal-memo.qmd`, `template-board-minutes.qmd`,
`template-corporate-resolution.qmd`, `template-board-pack.qmd`,
`template-strategy-paper.qmd`, `template-policy-document.qmd`,
`template-procedure-document.qmd`, `template-framework-document.qmd`,
`template-terms-conditions.qmd`, `template-dpa.qmd`,
`template-privacy-policy.qmd`, `template-non-compete.qmd`,
`template-cease-desist.qmd`) show
each block
filled in. The schema
for IDE completion lives in `_extensions/obsidian/_schema.yml`, and
front-matter snippets for each document type live in
`_extensions/obsidian/_snippets.json`.

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
  po-number: "PO-2026-0142"   # optional, shown in the header row
  date: "2026-08-15"
  supply-date: "2026-08-15"   # optional, shown in the header row
  due-date: "2026-08-29"   # optional, shown in the header row
  vat-status: "Not registered for VAT"   # optional, shown in the payment block
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
| `po-number` | Purchase order reference from the client, shown right-aligned in the header row; optional |
| `date` | Invoice date, shown right-aligned in the header row |
| `supply-date` | Date the goods or service were provided, shown right-aligned in the header row; optional. UK invoices must separate the supply date from the invoice date |
| `due-date` | Payment due date, shown right-aligned in the header row; optional |
| `vat-status` | VAT status line, shown in the payment block; optional. A below-threshold sole trader has no VAT number and should state that no VAT is charged, which removes the standard finance-team query |
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
| Primary text | `#121212` | 18.7:1 |
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
  filename, `SIL Open Font License`, `GUST Font License`, and the
  licence URLs in the NOTICE files. They are standard strings from
  their licences.
- `CODE_OF_CONDUCT.md` and `SECURITY.md`: supplied by the
  organisation's repository defaults, not maintained in this
  repository.
- `_extensions/obsidian/NOTICE`: the remaining hits are the fixed
  identifiers above and table cells that carry licence URLs.

The supply-chain record is `sbom.spdx.json`, generated by
`tools/make-sbom.py` (stdlib only). CI checks the package content for
freshness, so the committed SBOM cannot go stale. The document
namespace identifies the baseline the SBOM was generated from, and
may lag the release tag by one commit.

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
