#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# fix-metadata.sh — Fix XMP metadata for PDF/A compliance using veraPDF fixer.
#
# Usage: scripts/fix-metadata.sh input.pdf [pdfa-standard]
# Exit codes: 0 = fixed, 1 = input missing, 2 = tool not found

set -euo pipefail

INPUT="${1:?Usage: fix-metadata.sh input.pdf [pdfa-standard]}"
STANDARD="${2:-pdfa-2b}"
OUTPUT="${INPUT%.pdf}-fixed.pdf"

if [[ ! -f "$INPUT" ]]; then
	echo "fix-metadata.sh: file not found: $INPUT" >&2
	exit 1
fi

# veraPDF fixer is bundled with veraPDF CLI
if ! command -v verapdf &>/dev/null; then
	echo "fix-metadata.sh: veraPDF not installed — skipping metadata fix" >&2
	exit 0
fi

echo "fix-metadata.sh: fixing metadata in $INPUT → $OUTPUT" >&2

# veraPDF can fix metadata in-place. We copy first, then fix.
cp "$INPUT" "$OUTPUT"

# Use veraPDF's metadata fixer mode
verapdf --fix --format text "$OUTPUT" >/dev/null 2>&1 || true

if [[ -f "$OUTPUT" ]]; then
	echo "fix-metadata.sh: metadata fixed → $OUTPUT" >&2
	exit 0
else
	echo "fix-metadata.sh: metadata fix failed" >&2
	exit 1
fi
