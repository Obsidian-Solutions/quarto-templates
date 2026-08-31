#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# render.sh — Master orchestrator for the Obsidian Solutions render pipeline.
#
# Reads YAML front matter from the input .qmd file and chains:
#   render → validate → fix-metadata → convert-pdf-a → sign → encrypt
#
# Usage: scripts/render.sh path/to/document.qmd
# Exit codes: 0 = success, 1 = usage error, 2 = render failure, 3 = validation failure after all fix attempts

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT="${1:?Usage: render.sh path/to/document.qmd}"

if [[ ! -f "$INPUT" ]]; then
	echo "render.sh: file not found: $INPUT" >&2
	exit 1
fi

# --- Extract metadata from front matter ---
# YAML keys we care about. Falls back to defaults when absent.
extract_meta() {
	# Print the value of a YAML key from the front matter block (between --- lines).
	local key="$1" default="${2:-}"
	local in_fm=false value=""
	while IFS= read -r line; do
		if [[ "$line" == "---" ]]; then
			if $in_fm; then break; fi
			in_fm=true
			continue
		fi
		if $in_fm; then
			if [[ "$line" =~ ^${key}:[[:space:]]*(.*) ]]; then
				value="${BASH_REMATCH[1]}"
				# Strip surrounding quotes
				value="${value#\"}"
				value="${value%\"}"
				value="${value#\'}"
				value="${value%\'}"
			fi
		fi
	done <"$INPUT"
	echo "${value:-$default}"
}

PDF_STANDARD=$(extract_meta "pdf-standard" "")
DO_SIGN=$(extract_meta "sign" "false")
DO_ENCRYPT=$(extract_meta "encrypt" "false")
CLASSIFICATION=$(extract_meta "confidentiality" "$(extract_meta "classification" "")")

# Normalise booleans
to_bool() {
	case "${1,,}" in
	true | yes | on | 1) echo true ;;
	*) echo false ;;
	esac
}

DO_SIGN=$(to_bool "$DO_SIGN")
DO_ENCRYPT=$(to_bool "$DO_ENCRYPT")

# --- GSCP auto-defaults ---
# When classification is set, auto-enable security features.
if [[ -n "$CLASSIFICATION" ]]; then
	case "${CLASSIFICATION^^}" in
	OFFICIAL-SENSITIVE | SECRET | "TOP SECRET")
		DO_SIGN=true
		DO_ENCRYPT=true
		[[ -z "$PDF_STANDARD" ]] && PDF_STANDARD="a-4f"
		echo "render.sh: GSCP ${CLASSIFICATION} — auto-enabled sign + encrypt + PDF/A-4f" >&2
		;;
	OFFICIAL)
		[[ -z "$PDF_STANDARD" ]] && PDF_STANDARD="a-2b"
		echo "render.sh: GSCP OFFICIAL — auto-enabled validate (PDF/A-2b)" >&2
		;;
	esac
fi

# --- Step 1: Render ---
PDF_OUTPUT="${INPUT%.qmd}.pdf"
echo "render.sh: rendering $INPUT → $PDF_OUTPUT" >&2

# Find project root (directory containing _quarto.yml)
PROJECT_ROOT=""
while IFS= read -r -d '' f; do
	PROJECT_ROOT="$(dirname "$f")"
	break
done < <(find "$(pwd)" -name '_quarto.yml' -print0 -maxdepth 3 2>/dev/null)

# Try Quarto first, fall back to direct pandoc
if command -v quarto &>/dev/null; then
	quarto render "$INPUT" --to pdf 2>&1
elif command -v pandoc &>/dev/null; then
	pandoc "$INPUT" -o "$PDF_OUTPUT" --pdf-engine=lualatex 2>&1
else
	echo "render.sh: neither quarto nor pandoc found — cannot render" >&2
	exit 2
fi

# Check output location. Quarto may redirect to _output/ via output-dir in _quarto.yml.
if [[ ! -f "$PDF_OUTPUT" ]]; then
	# Ponytail: _output/ fallback is project-layout specific, not a hack.
	# If _quarto.yml output-dir changes, update this fallback too.
	OUTPUT_SUBDIR="${PDF_OUTPUT}"
	if [[ -n "$PROJECT_ROOT" && -f "${PROJECT_ROOT}/_output/${OUTPUT_SUBDIR}" ]]; then
		PDF_OUTPUT="${PROJECT_ROOT}/_output/${OUTPUT_SUBDIR}"
	elif [[ -f "_output/${OUTPUT_SUBDIR}" ]]; then
		PDF_OUTPUT="_output/${OUTPUT_SUBDIR}"
	fi
fi

if [[ ! -f "$PDF_OUTPUT" ]]; then
	echo "render.sh: render failed — no output PDF" >&2
	exit 2
fi

CURRENT_PDF="$PDF_OUTPUT"

# --- Step 2: Validate ---
if [[ -n "$PDF_STANDARD" ]]; then
	echo "render.sh: validating with veraPDF ($PDF_STANDARD)" >&2
	if "$SCRIPT_DIR/validate.sh" "$CURRENT_PDF" --standard "$PDF_STANDARD"; then
		echo "render.sh: validation passed" >&2
	else
		echo "render.sh: validation failed — attempting fix" >&2

		# Try metadata fix first (lighter)
		FIXED="${CURRENT_PDF%.pdf}-fixed.pdf"
		if "$SCRIPT_DIR/fix-metadata.sh" "$CURRENT_PDF" "$PDF_STANDARD" 2>/dev/null; then
			if "$SCRIPT_DIR/validate.sh" "$FIXED" --standard "$PDF_STANDARD" 2>/dev/null; then
				CURRENT_PDF="$FIXED"
				echo "render.sh: metadata fix succeeded" >&2
			else
				echo "render.sh: metadata fix insufficient — trying Ghostscript" >&2
			fi
		fi

		# If metadata fix didn't work, try full re-conversion
		if [[ "$CURRENT_PDF" == "$PDF_OUTPUT" ]]; then
			RECONVERTED="${CURRENT_PDF%.pdf}-pdfa.pdf"
			if "$SCRIPT_DIR/convert-pdf-a.sh" "$CURRENT_PDF" "$PDF_STANDARD" 2>/dev/null; then
				CURRENT_PDF="$RECONVERTED"
				echo "render.sh: Ghostscript conversion succeeded" >&2
			else
				echo "render.sh: all fix attempts failed" >&2
				exit 3
			fi
		fi
	fi
fi

# --- Step 3: Sign ---
if [[ "$DO_SIGN" == "true" ]]; then
	echo "render.sh: signing document" >&2
	SIGNED="${CURRENT_PDF%.pdf}-signed.pdf"
	if "$SCRIPT_DIR/sign.sh" "$CURRENT_PDF" "$SIGNED" 2>&1; then
		CURRENT_PDF="$SIGNED"
		echo "render.sh: signing succeeded" >&2
	else
		echo "render.sh: signing skipped (missing cert/key or pyHanko)" >&2
	fi
fi

# --- Step 4: Encrypt ---
if [[ "$DO_ENCRYPT" == "true" ]]; then
	echo "render.sh: encrypting document" >&2
	ENCRYPTED="${CURRENT_PDF%.pdf}-encrypted.pdf"
	if "$SCRIPT_DIR/encrypt.sh" "$CURRENT_PDF" "$ENCRYPTED" 2>&1; then
		CURRENT_PDF="$ENCRYPTED"
		echo "render.sh: encryption succeeded" >&2
	else
		echo "render.sh: encryption skipped (missing qpdf)" >&2
	fi
fi

# --- Final output ---
if [[ "$CURRENT_PDF" != "$PDF_OUTPUT" ]]; then
	cp "$CURRENT_PDF" "$PDF_OUTPUT"
	echo "render.sh: final output → $PDF_OUTPUT" >&2
fi

echo "render.sh: done" >&2
exit 0
