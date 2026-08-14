// SPDX-License-Identifier: MIT
// obsidian-doc: Obsidian Solutions controlled business document
// template for the Typst engine.
//
// This is the lightweight Typst companion to the LaTeX formats. It
// carries the same front-matter surface and the same identity:
// classification marking on the cover and every page, a cover page
// with title block and identity line, house typography (Montserrat
// headings, TeX Gyre Pagella body) and the house palette. render.sh
// attaches the PDF/A-4f provenance (source and manifest) after the
// render with attach-provenance.py, so the Typst archive is as
// self-contained as the LaTeX one. The LaTeX log gates do not
// apply; the STE, font and PDF/UA gates do.
//
// The palette mirrors brand.yml:
//   primary #121212 (text), secondary #484949 (muted),
//   ruled #cecece (hairlines), surface #f3f3f3.
// Keep the two files in step.

#let obsidian-colors = (
  primary: rgb("#121212"),
  secondary: rgb("#484949"),
  ruled: rgb("#cecece"),
  surface: rgb("#f3f3f3"),
  white: rgb("#ffffff"),
)

// Full-page colour band for the cover, so the Typst output can use
// the banded look without LaTeX.
#let band-colors = (
  maroon: rgb("#522b45"),
  slate: rgb("#313d47"),
  gold: rgb("#ffdb00"),
  yellow: rgb("#ffdd00"),
)

// Identity line: "reference | edition | review-date", skipping the
// parts that are not set.
#let identity-line(reference, edition, review-date) = {
  // Join the set fields into "a | b | c" as content. Missing
  // fields are skipped; separators only sit between present values.
  let parts = ()
  if reference != none { parts = parts + (reference,) }
  if edition != none { parts = parts + (edition,) }
  if review-date != none { parts = parts + (review-date,) }
  let n = parts.len()
  let out = none
  for i in range(n) {
    out = if out == none {
      parts.at(i)
    } else {
      out + " | " + parts.at(i)
    }
  }
  if out == none { [] } else { out }
}
// ---- Cover, plain: white with the house identity line ----
#let plain-cover(
  title, subtitle, author, date, confidentiality, reference, edition, review-date, doc-type, version, heading-font, logo,
) = {
  // Brand mark top-left, classification top-right on the same row,
  // mirroring the LaTeX cover layout.
  if logo != none or confidentiality != none {
    grid(
      columns: (1fr, auto),
      align(left)[
        #if logo != none [
          #image(logo, width: 4cm)
        ]
      ],
      align(right)[
        #if confidentiality != none [
          #text(size: 9pt, weight: "bold", fill: obsidian-colors.secondary, upper(confidentiality))
        ]
      ],
    )
    v(3cm)
  } else {
    v(3cm)
  }

  // Label and title block.
  if doc-type != none {
    text(size: 11pt, weight: "bold", fill: obsidian-colors.secondary, upper(doc-type))
    v(0.5em)
  }
  text(font: heading-font, size: 24pt, weight: "bold", fill: obsidian-colors.primary, title)
  if subtitle != none {
    v(0.5em)
    text(size: 13pt, fill: obsidian-colors.secondary, subtitle)
  }
  v(1em)
  line(length: 40%, stroke: 0.8pt + obsidian-colors.primary)
  v(1.5em)

  if author != none {
    text(size: 12pt, author)
    v(0.5em)
  }
  if date != none {
    text(size: 10pt, fill: obsidian-colors.secondary, date)
  }
  if version != none {
    v(0.5em)
    text(size: 10pt, fill: obsidian-colors.secondary, [#"Version: " #version])
  }

  v(1fr)

  // Identity line at the bottom.
  align(center)[
    #text(size: 9pt, fill: obsidian-colors.secondary, identity-line(reference, edition, review-date))
  ]
  pagebreak()
}

// ---- Cover, banded: full-page colour band ----
// The dark brand mark would vanish on the dark band, so the banded
// cover omits it (the plain cover shows it). The logo parameter is
// accepted for signature uniformity and unused, like the LaTeX
// banded themes.
#let banded-cover(
  title, subtitle, author, date, confidentiality, reference, edition, review-date, cover, doc-type, heading-font, logo, margin,
) = {
  let band = if cover == "banded-slate" { band-colors.slate } else { band-colors.maroon }
  let rule-color = if cover == "banded-slate" { band-colors.yellow } else { band-colors.gold }

  // Full-page band. place() without an alignment anchors the box at
  // the top-left of the page frame; the negative dx/dy stretch it
  // over the margins so the band reaches the paper edge.
  set page(background: none)
  place(
    dx: -margin.left,
    dy: -margin.top,
    box(width: 100% + margin.left + margin.right, height: 100% + margin.top + margin.bottom, fill: band),
  )

  // Classification, white, top right.
  if confidentiality != none {
    align(right)[
      #text(size: 9pt, weight: "bold", fill: obsidian-colors.white, upper(confidentiality))
    ]
  }
  v(3cm)

  if doc-type != none {
    text(size: 11pt, weight: "bold", fill: obsidian-colors.white, upper(doc-type))
    v(0.5em)
  }
  text(font: heading-font, size: 24pt, weight: "bold", fill: obsidian-colors.white, title)
  if subtitle != none {
    v(0.5em)
    text(size: 13pt, fill: obsidian-colors.white, subtitle)
  }
  v(1.5em)
  line(length: 40%, stroke: 1.5pt + rule-color)
  v(1.5em)

  if author != none {
    text(size: 12pt, fill: obsidian-colors.white, author)
    v(0.5em)
  }
  if date != none {
    text(size: 10pt, fill: obsidian-colors.white, date)
  }

  v(1fr)

  align(center)[
    #text(size: 9pt, fill: obsidian-colors.white, identity-line(reference, edition, review-date))
  ]
  pagebreak()
}

#let doc(
  // Metadata surface, mirroring the LaTeX front matter.
  title: none,
  subtitle: none,
  author: none,
  date: none,
  lang: "en",
  region: "GB",
  reference: none,
  version: none,
  confidentiality: none,
  doc-type: none,
  edition: none,
  review-date: none,
  keywords: (),
  // Cover variant: "plain" (white) or "banded" / "banded-slate".
  cover: "plain",
  // Brand mark on the cover, top-left. The default is bundled in the
  // package directory, which is the Typst compile root for Quarto
  // renders. Pass `logo: none` to omit it.
  logo: "obsidian-logo.png",
  // Font stack: Montserrat headings, serif body.
  heading-font: "Montserrat",
  body-font: ("TeX Gyre Pagella", "Georgia", "Liberation Serif"),
  fontsize: 11pt,
  // Margins, A4 portrait.
  margin: (top: 2.4cm, bottom: 2.4cm, left: 2.2cm, right: 2.2cm),
  // Honor the document's number-sections flag, matching the LaTeX
  // formats. References (@sec-x) still need numbering on the target,
  // exactly as in LaTeX: a document that cites sections must keep
  // numbering on.
  number-sections: false,
  body,
) = {

  // ---- Document metadata ----
  // The metadata surface needs a string for the author; the show
  // rule passes a string array already, so pass it straight through.
  set document(
    title: title,
    author: if author != none { author } else { () },
    keywords: keywords,
  )

  // ---- Page: A4 portrait, house margins, page numbers ----
  set page(
    paper: "a4",
    margin: margin,
    numbering: "1",
    number-align: center + bottom,
  )

  // ---- Typography ----
  set text(font: body-font, size: fontsize, lang: lang, region: region)
  set par(justify: true, leading: 0.65em)
  // Numbered sections only when the document asks (number-sections).
  // The pattern "1.1" gives the full hierarchy (1, 1.1, 1.1.1): a
  // bare "1" would render a subsection as "11" with no separator.
  // References (@sec-x / @fig-x) resolve only when the target carries
  // numbering, so a document that cites sections or figures must keep
  // numbering on (same rule as LaTeX).
  set heading(numbering: if number-sections { "1.1" } else { none })
  // Heading style: house sans display face, primary colour. Typst
  // 0.13 styles headings through a show rule, not set heading args.
  show heading: set text(font: heading-font, fill: obsidian-colors.primary, weight: 600)
  show link: set text(fill: obsidian-colors.secondary)

  // Tables: booktabs-style, top and bottom rules only.
  set table(stroke: none, inset: (x: 6pt, y: 4pt))
  show table.cell.where(y: 0): set text(weight: "bold")
  show table.cell: set block(above: 0.25em, below: 0.25em)

  // ---- Running header and footer ----
  // The cover page carries its own classification and identity
  // line, so the header and footer fire only on the body pages.
  set page(
    header: context {
      if counter(page).get().first() > 1 and confidentiality != none {
        text(size: 8pt, weight: "bold", fill: obsidian-colors.secondary, upper(confidentiality))
      }
      h(1fr)
      if counter(page).get().first() > 1 and reference != none {
        text(size: 8pt, fill: obsidian-colors.secondary, reference)
      }
    },
    footer: context {
      if counter(page).get().first() > 1 and (edition != none or review-date != none) {
        text(size: 8pt, fill: obsidian-colors.secondary, identity-line(reference, edition, review-date))
      }
    },
  )

  // ---- Cover page ----
  if cover == "banded" or cover == "banded-slate" {
    banded-cover(title, subtitle, author, date, confidentiality, reference, edition, review-date, cover, doc-type, heading-font, logo, margin)
  } else {
    plain-cover(title, subtitle, author, date, confidentiality, reference, edition, review-date, doc-type, version, heading-font, logo)
  }

  // ---- Body ----
  body
}
