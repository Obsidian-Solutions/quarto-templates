// SPDX-License-Identifier: MIT
// Import the bundled obsidian-doc template package. Quarto resolves
// @preview/<name>:<version> from the extension's
// typst/packages/preview/ directory (a local package cache).
// Imported as "obsidian-doc" (not "doc") so the name never collides
// with pandoc's show-rule variable.
#import "@preview/obsidian-doc:0.1.0": doc as obsidian-doc
