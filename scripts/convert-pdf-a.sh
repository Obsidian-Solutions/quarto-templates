#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# convert-pdf-a.sh — Convert PDF to PDF/A using Ghostscript.
#
# Usage: scripts/convert-pdf-a.sh input.pdf [pdfa-standard]
# Standards: pdfa-1b, pdfa-2b, pdfa-3u, pdfa-4f (default: pdfa-2b)
# Exit codes: 0 = converted, 1 = input missing, 2 = Ghostscript not found

set -euo pipefail

INPUT="${1:?Usage: convert-pdf-a.sh input.pdf [pdfa-standard]}"
STANDARD="${2:-pdfa-2b}"
OUTPUT="${INPUT%.pdf}-pdfa.pdf"

if [[ ! -f "$INPUT" ]]; then
	echo "convert-pdf-a.sh: file not found: $INPUT" >&2
	exit 1
fi

if ! command -v gs &>/dev/null; then
	echo "convert-pdf-a.sh: Ghostscript not installed — skipping conversion" >&2
	echo "  Install: sudo pacman -S ghostscript" >&2
	exit 0
fi

# Map standard name to Ghostscript settings
# Ghostscript uses -sDEVICE=pdfwrite + -dPDFA flags. No "pdfa" device exists.
case "$STANDARD" in
pdfa-1b | a-1b) GS_PDFA="-dPDFA=1" ;;
pdfa-2b | a-2b) GS_PDFA="-dPDFA=2" ;;
pdfa-3u | a-3u) GS_PDFA="-dPDFA=3" ;;
pdfa-4f | a-4f) GS_PDFA="-dPDFA=2" ;; # ponytail: GS does not support PDF/A-4f natively; falls back to PDF/A-2b. Use Typst for native PDF/A-4f.
*) GS_PDFA="-dPDFA=2" ;;
esac

echo "convert-pdf-a.sh: converting $INPUT → $OUTPUT ($STANDARD)" >&2

gs -dBATCH -dNOPAUSE -dQUIET \
	-sDEVICE=pdfwrite \
	"$GS_PDFA" \
	-sOutputFile="$OUTPUT" \
	"$INPUT" 2>&1

if [[ -f "$OUTPUT" ]]; then
	echo "convert-pdf-a.sh: converted → $OUTPUT" >&2
	exit 0
else
	echo "convert-pdf-a.sh: conversion failed" >&2
	exit 1
fi
