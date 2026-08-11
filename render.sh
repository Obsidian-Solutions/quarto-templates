#!/usr/bin/env bash
# Render a document with baseline stamping.
# Usage: ./render.sh [file.qmd]
# The baseline (commit hash and date) is stamped into the cover and
# footer so the PDF is traceable to the repository state.
set -euo pipefail

FILE="${1:-example.qmd}"
HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
DATE=$(date +%Y-%m-%d)

quarto render "$FILE" -M baseline="$HASH, $DATE"
