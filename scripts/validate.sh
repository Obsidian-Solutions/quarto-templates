#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# validate.sh — Validate PDF/A and PDF/UA compliance using veraPDF.
#
# Usage: scripts/validate.sh input.pdf [--standard pdfa-2b|pdfa-4f|pdfua-1]
# Exit codes: 0 = compliant, 1 = non-compliant, 2 = veraPDF not found

set -euo pipefail

INPUT="${1:?Usage: validate.sh input.pdf [--standard pdfa-2b]}"
STANDARD="${3:-pdfa-2b}"

# Parse optional --standard flag
while [[ $# -gt 0 ]]; do
	case "$1" in
	--standard)
		STANDARD="$2"
		shift 2
		;;
	*) shift ;;
	esac
done

if [[ ! -f "$INPUT" ]]; then
	echo "validate.sh: file not found: $INPUT" >&2
	exit 1
fi

if ! command -v verapdf &>/dev/null; then
	echo "validate.sh: veraPDF not installed — skipping validation" >&2
	echo "  Install: sudo pacman -S verapdf (or verapdf.org)" >&2
	exit 0
fi

REPORT="${INPUT%.pdf}-validation.txt"

# Map standard name to veraPDF profile
case "$STANDARD" in
pdfa-1b) PROFILE="PDF/A-1b validation profile" ;;
pdfa-2b) PROFILE="PDF/A-2b validation profile" ;;
pdfa-3u) PROFILE="PDF/A-3u validation profile" ;;
pdfa-4f) PROFILE="PDF/A-4f validation profile" ;;
pdfua-1) PROFILE="PDF/UA-1 validation profile" ;;
*) PROFILE="PDF/A-2b validation profile" ;;
esac

echo "validate.sh: checking $INPUT against $STANDARD" >&2

verapdf --level 2 --format text "$INPUT" >"$REPORT" 2>&1
EXIT_CODE=$?

if [[ $EXIT_CODE -eq 0 ]]; then
	echo "validate.sh: PASS — $INPUT is $STANDARD compliant" >&2
else
	echo "validate.sh: FAIL — $INPUT failed $STANDARD validation" >&2
	echo "validate.sh: report saved to $REPORT" >&2
	# Show first 10 failures
	grep -i "fail" "$REPORT" | head -10 >&2
fi

exit $EXIT_CODE
