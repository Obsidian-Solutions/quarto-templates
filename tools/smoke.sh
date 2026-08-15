#!/bin/bash
# SPDX-License-Identifier: MIT
# smoke.sh - quick full-format sanity check on one document.
#
# Renders DOC through every format the template contributes, checking
# each output exists and the render exited 0. Unlike render.sh it does
# not run the full verification gates (no veraPDF, no provenance, no
# STE) - it is the fast feedback loop for a document change, not the
# release gate. Run the full render.sh in CI for the real checks.
#
# Usage:  tools/smoke.sh DOC.qmd [DOC2.qmd ...]
# Exit:   0 when every requested format rendered, 1 otherwise.
set -u

FAIL=0
for FILE in "$@"; do
  [ -f "$FILE" ] || { echo "smoke: not found: $FILE"; FAIL=1; continue; }
  BASE="${FILE%.qmd}"
  echo "smoke: $FILE"
  for FMT in obsidian-pdf obsidian-html obsidian-docx obsidian-epub \
             obsidian-revealjs obsidian-beamer obsidian-pptx \
             obsidian-dashboard obsidian-typst; do
    # A format that the document does not declare still renders when
    # forced; the point is that nothing in the extension breaks.
    OUT="${BASE}-smoke"
    if quarto render "$FILE" --to "$FMT" --output-dir "$OUT" \
        > /tmp/smoke-$$.log 2>&1; then
      echo "  ok $FMT"
    else
      echo "  FAIL $FMT"
      # Surface the real failure: error-pattern lines first (the
      # LaTeX engine prints the meaningful diagnostics), then the
      # tail so a missing-package or missing-file cause is visible
      # in CI instead of only the generic 'see the log' hint.
      grep -nE "! [A-Z]|LaTeX Error|Package [^ ]* Error|Undefined control|Fatal error|error:|not found|No such file|cannot|Error running filter" /tmp/smoke-$$.log | head -8
      echo "  --- tail ---"
      tail -20 /tmp/smoke-$$.log
      FAIL=1
    fi
    rm -rf "$OUT"
  done
done
rm -f /tmp/smoke-$$.log
exit "$FAIL"
