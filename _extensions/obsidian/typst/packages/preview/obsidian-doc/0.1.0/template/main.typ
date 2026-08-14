// SPDX-License-Identifier: MIT
// Standalone entry point for the obsidian-doc package, used for
// direct typst compile checks and package validation. Quarto renders
// use typst-show.typ instead (mapping Pandoc metadata).
#import "../lib.typ": doc

#show: doc.with(
  title: "Example Policy Document",
  subtitle: "Showing the Typst format",
  author: "Obsidian Solutions",
  date: "2026-08-14",
  reference: "OS-DOC-004",
  version: "1.0.0",
  confidentiality: "Commercial in Confidence",
  doc-type: "Policy Document",
  edition: "First Edition",
  review-date: "February 2027",
)

#heading(level: 1)[Introduction]

This is a controlled business document rendered with the Typst
engine. It carries the same identity as the LaTeX formats.

#heading(level: 2)[Purpose]

A numbered section below shows the heading treatment.

#heading(level: 1)[Conclusion]

The Typst format is a fast companion to the archival PDF.
