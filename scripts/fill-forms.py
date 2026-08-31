#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# fill-forms.py — Wrapper that runs fill_forms.py via uv.
# Usage: scripts/fill-forms.py input.pdf data.yaml output.pdf [--interactive]
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec uv run --project "$SCRIPT_DIR" python3 "$SCRIPT_DIR/fill_forms.py" "$@"
