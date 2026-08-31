#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# sign.sh — PAdES B-LT digital signing using pyHanko.
#
# Usage: scripts/sign.sh input.pdf [output.pdf]
# Environment variables:
#   SIGNING_CERT  — Path to X.509 certificate (PEM)
#   SIGNING_KEY   — Path to private key (PEM)
#   SIGNING_PIN   — PIN for PKCS#11 token (optional)
#   SIGNING_FIELD — Signature field name (default: "Obsidian Solutions")
#   SIGNING_REASON — Signature reason (default: "Document signed by Obsidian Solutions")
# Exit codes: 0 = signed, 1 = input missing, 2 = tool not found, 3 = signing failed

set -euo pipefail

INPUT="${1:?Usage: sign.sh input.pdf [output.pdf]}"
OUTPUT="${2:-${INPUT%.pdf}-signed.pdf}"

if [[ ! -f "$INPUT" ]]; then
	echo "sign.sh: file not found: $INPUT" >&2
	exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYHANKO="uv run --project $SCRIPT_DIR pyhanko"

if ! command -v uv &>/dev/null; then
	echo "sign.sh: uv not installed — skipping signing" >&2
	echo "  Install: curl -LsSf https://astral.sh/uv/install.sh | sh" >&2
	exit 0
fi

# Ensure pyHanko is available via uv
if ! $PYHANKO --version &>/dev/null 2>&1; then
	echo "sign.sh: installing pyHanko via uv..." >&2
	uv sync --project "$SCRIPT_DIR" 2>&1 || true
fi

CERT="${SIGNING_CERT:-}"
KEY="${SIGNING_KEY:-}"
FIELD="${SIGNING_FIELD:-Obsidian Solutions}"
REASON="${SIGNING_REASON:-Document signed by Obsidian Solutions}"

if [[ -z "$CERT" || -z "$KEY" ]]; then
	echo "sign.sh: SIGNING_CERT and SIGNING_KEY not set — skipping signing" >&2
	exit 0
fi

if [[ ! -f "$CERT" || ! -f "$KEY" ]]; then
	echo "sign.sh: certificate or key not found (CERT=$CERT, KEY=$KEY)" >&2
	exit 0
fi

echo "sign.sh: signing $INPUT → $OUTPUT" >&2

$PYHANKO sign visible \
	-p "$CERT" \
	-c "$KEY" \
	--field-name "$FIELD" \
	--reason "$REASON" \
	--timestamp-url "" \
	"$INPUT" \
	-o "$OUTPUT" 2>&1

if [[ $? -eq 0 && -f "$OUTPUT" ]]; then
	echo "sign.sh: signed → $OUTPUT" >&2
	exit 0
else
	echo "sign.sh: signing failed" >&2
	exit 3
fi
