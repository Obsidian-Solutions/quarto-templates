// SPDX-License-Identifier: MIT
// Import the bundled obsidian-doc template package. Quarto resolves
// @preview/<name>:<version> from the extension's
// typst/packages/preview/ directory (a local package cache).
// Imported as "doc" — the name pandoc's show-rule references in
// typst-show.typ. No alias: the function must be reachable as `doc`.
#import "@preview/obsidian-doc:0.1.0": doc
