#!/bin/bash
# SPDX-License-Identifier: MIT
# Render the cover-theme showcase once per theme.
#
# The obsidian-pdf format ships eight titlepage themes (plain,
# formal, classic-lined, colorbox, academic, bg-image, banded,
# banded-slate). This script renders examples/template-covers.qmd
# once per theme into examples/covers/ so the whole family is
# visible from one source. Each theme is selected by a per-theme
# metadata file (the format-block titlepage key).
#
# Usage: tools/render-covers.sh
set -euo pipefail

SRC="examples/template-covers.qmd"
OUT="examples/covers"
# The repo project sets output-dir: _output, so the rendered PDF
# lands there (via the -o name), not next to the source.
QUARTO_OUT="_output"
THEMES="plain formal classic-lined colorbox academic bg-image banded banded-slate"

# The PDF format embeds manifest.json (provenance) via embed.lua;
# write it next to the source exactly as render.sh does, and remove
# it after, so the cover renders resolve the embed file.
MANIFEST="$(dirname "$SRC")/manifest.json"
printf '{\n  "document": "%s",\n  "baseline": "covers",\n  "rendered": "covers"\n}\n' \
  "$(basename "$SRC")" > "$MANIFEST"

mkdir -p "$OUT"
for theme in $THEMES; do
  meta="$OUT/theme-$theme.yml"
  if [ "$theme" = "bg-image" ]; then
    # The theme errors without an image; the bundled corner motif is
    # the showcase's background (format-resources flatten to the
    # render root, so the bare filename resolves).
    printf 'format:\n  obsidian-pdf:\n    titlepage: %s\n    titlepage-bg-image: corner-bg.png\n' "$theme" > "$meta"
  else
    printf 'format:\n  obsidian-pdf:\n    titlepage: %s\n' "$theme" > "$meta"
  fi
  echo "==> $theme"
    quarto render "$SRC" --metadata-file "$meta" -o "covers-$theme.pdf"
    mv "$QUARTO_OUT/covers-$theme.pdf" "$OUT/"
    rm -f "$meta"
done
# Drop the LaTeX intermediates a direct render leaves next to the
# source, and keep the build record: move the .log into the covers
# output like render.sh does (the rest are regenerable).
SRC_LOG="$(dirname "$SRC")/$(basename "$SRC" .qmd).log"
[ -f "$SRC_LOG" ] && mv "$SRC_LOG" "$OUT/$(basename "$SRC" .qmd).log"
rm -f "$(dirname "$SRC")/$(basename "$SRC" .qmd)".{aux,lot,toc,lof,out}
rm -f "$MANIFEST"

echo "Rendered ${THEMES} -> ${OUT}/covers-<theme>.pdf"
