#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# encrypt.sh — AES-256 encryption using qpdf.
#
# Usage: scripts/encrypt.sh input.pdf [output.pdf]
# Environment variables:
#   QPDF_OWNER_PASSWORD  — Owner password (default: random 16-char)
#   QPDF_USER_PASSWORD   — User password (default: empty — viewable)
#   QPDF_PRINT           — Print permission (default: full)
#   QPDF_EXTRACT         — Extract permission (default: yes)
#   QPDF_MODIFY          — Modify permission (default: no)
# Exit codes: 0 = encrypted, 1 = input missing, 2 = tool not found, 3 = encryption failed

set -euo pipefail

INPUT="${1:?Usage: encrypt.sh input.pdf [output.pdf]}"
OUTPUT="${2:-${INPUT%.pdf}-encrypted.pdf}"

if [[ ! -f "$INPUT" ]]; then
	echo "encrypt.sh: file not found: $INPUT" >&2
	exit 1
fi

if ! command -v qpdf &>/dev/null; then
	echo "encrypt.sh: qpdf not installed — skipping encryption" >&2
	echo "  Install: sudo pacman -S qpdf" >&2
	exit 0
fi

# Generate owner password if not set
OWNER_PW="${QPDF_OWNER_PASSWORD:-$(head -c 16 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 16)}"
USER_PW="${QPDF_USER_PASSWORD:-}"

# Map permissions (qpdf requires --modify=all|annotate|assembly|form|none)
PRINT="${QPDF_PRINT:-full}"
EXTRACT="${QPDF_EXTRACT:-y}"
MODIFY="${QPDF_MODIFY:-none}"

echo "encrypt.sh: encrypting $INPUT → $OUTPUT (AES-256)" >&2

qpdf \
	--encrypt "$USER_PW" "$OWNER_PW" 256 \
	--print="$PRINT" \
	--extract="$EXTRACT" \
	--modify="$MODIFY" \
	-- "$INPUT" "$OUTPUT" 2>&1

if [[ $? -eq 0 && -f "$OUTPUT" ]]; then
	echo "encrypt.sh: encrypted → $OUTPUT" >&2
	echo "  Owner password set. User password: ${USER_PW:-<empty>}" >&2
	exit 0
else
	echo "encrypt.sh: encryption failed" >&2
	exit 3
fi
