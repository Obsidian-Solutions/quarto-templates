#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Render a document with baseline stamping, then optimise and
# optionally encrypt a distribution copy.
#
# Usage: ./render.sh [file.qmd]
#
# The baseline (commit hash and date) is stamped into the cover and
# footer so the PDF is traceable to the repository state.
#
# Distribution copy:
#   The master PDF stays a clear PDF/A-4f archive (PDF/A forbids
#   encryption). qpdf creates a smaller, optionally encrypted copy:
#     <file>-dist.pdf   optimised (object streams, recompressed)
#     <file>-enc.pdf    AES-256 encrypted, if passwords are supplied
#
# Encryption is enabled ONLY when the environment variables below are
# set. Passwords never live in the document or in this repository:
#   OS_DOC_USER_PASSWORD   user password (opens the PDF)
#   OS_DOC_OWNER_PASSWORD  owner password (lifts permissions)
#                         (defaults to the user password if unset)
#
# Verification gates fail loudly when their tool is missing, so a
# clean render is never a false green. GATE_SKIP names gates to
# disable deliberately (comma-separated: provenance,pdffonts,pdfua,
# ste). The LaTeX engine runs the page-overflow and cross-reference
# gates from its log; the Typst engine attaches provenance instead
# and shares the STE, font-embedding and PDF/UA gates.
set -euo pipefail

FILE="${1:-examples/template.qmd}"
HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
DATE=$(date +%Y-%m-%d)
BASE="${FILE%.qmd}"
SRC_DIR="$(dirname "$FILE")"
# Quarto runs the PDF engine in the source file's directory, so the
# embed filter resolves its attach paths relative to that directory.
# The manifest must sit next to the source.
# Quarto routes project renders to the project output-dir (_quarto.yml
# sets _output). Override with OUTPUT_DIR=... if a project differs.
OUT="${OUTPUT_DIR:-_output}"

# Control manifest: embedded into the PDF so the archive is
# self-contained provenance. The embed.lua filter attaches it (and
# the source) via LaTeX's embedfile package. The timestamp is full
# ISO-8601 with the local UTC offset, so two builds of the same
# baseline are distinguishable.
RENDERED=$(date +%Y-%m-%dT%H:%M:%S%z)
cat > "${SRC_DIR}/manifest.json" <<EOF
{
  "document": "$BASE",
  "baseline": "$HASH",
  "rendered": "$RENDERED"
}
EOF

# Engine detection. The Typst format has no LaTeX log and its PDF/A-4f
# provenance must be attached post-render (Typst has no embed
# primitive); the LaTeX path embeds the source during the run. The
# STE, font-embedding and PDF/UA gates are engine-independent and run
# for both.
if grep -qE "obsidian-typst" "$FILE" 2>/dev/null \
   || grep -qE "obsidian-typst" "${FILE%.qmd}.yml" 2>/dev/null \
   || [[ "${QUARTO_TO:-}" == "obsidian-typst" ]]; then
  ENGINE=typst
else
  ENGINE=latex
fi

quarto render "$FILE" -M baseline="$HASH, $DATE"

if [ "$ENGINE" = "typst" ]; then
  # Typst overflow gate. Typst warns "content does not fit" when a
  # block overflows its frame; the warning lands on stderr during the
  # render. The render above already surfaced it; fail loudly here if
  # the output claims success but Typst warned.
  # Provenance: attach the source (and the manifest) with the
  # AFRelationship + MIME keys PDF/A-4f requires. The tool needs
  # pikepdf; absent, the gate fails (a Typst PDF/A-4f claim without
  # embedded provenance is a false green). The interpreter is found
  # in order: an explicit PIKEPDF_PY, a python3 with pikepdf
  # importable, or the pdf2quarto venv (a known pikepdf host).
  PIKEPDF_PY="${PIKEPDF_PY:-}"
  if [ -z "$PIKEPDF_PY" ]; then
    if python3 -c "import pikepdf" 2>/dev/null; then
      PIKEPDF_PY=python3
    elif [ -x /home/matt/Documents/Writing/pdf2quarto/.venv/bin/python ]; then
      PIKEPDF_PY=/home/matt/Documents/Writing/pdf2quarto/.venv/bin/python
    fi
  fi
  if [ -x "$(dirname "$0")/tools/attach-provenance.py" ] && [ -n "$PIKEPDF_PY" ]; then
    "$PIKEPDF_PY" "$(dirname "$0")/tools/attach-provenance.py" \
      "${OUT}/${BASE}.pdf" "$FILE" "${SRC_DIR}/manifest.json"
  elif [[ ",${GATE_SKIP:-}," != *",provenance,"* ]]; then
    echo "GATE provenance: attach-provenance.py or pikepdf missing; set GATE_SKIP=provenance to skip" >&2
    exit 1
  fi
else
  # Page-overflow gate (LaTeX). LaTeX reports content wider or taller
  # than the printable area as Overfull \hbox / \vbox warnings in its
  # log. The format sets latex-clean: false so the log survives; fail
  # the render when any overfull box is present, so no document ships
  # with content clipped at a margin. Underfull is cosmetic (loose
  # spacing), not clipping, so it is not a failure.
  # The LaTeX log. Quarto runs the engine with the project root as
  # the working directory, so the log lands next to the intermediate
  # .tex at the root even when the output-dir is set; check both.
  LOG="${BASE}.log"
  [ -f "$LOG" ] || LOG="${OUT}/${BASE}.log"
  if [ -f "$LOG" ] && grep -qE "Overfull \\\\(h|v)box" "$LOG"; then
    echo "PAGE OVERFLOW DETECTED in $FILE:"
    grep -nE "Overfull" "$LOG"
    exit 1
  fi

  # Cross-reference gate. A broken \ref or \cite prints "??" and a
  # LaTeX warning; fail the render so no document ships with dead
  # links or missing bibliography entries.
  if [ -f "$LOG" ] && grep -qE "LaTeX Warning: .* undefined" "$LOG"; then
    echo "UNDEFINED CROSS-REFERENCE in $FILE:"
    grep -nE "LaTeX Warning: .* undefined" "$LOG"
    exit 1
  fi
fi

# Font-embedding pre-flight. veraPDF is the definitive PDF/A gate but
# is optional to install; pdffonts (poppler) is a fast check that
# every font is embedded (emb) with a ToUnicode map (uni), which
# PDF/A requires for text extraction. Fails on a missing or
# incomplete embedding before the slower veraPDF run. A render with
# the tool absent fails too: a "clean" PDF without the check is a
# false green. GATE_SKIP=pdffonts disables the gate deliberately.
if ! command -v pdffonts >/dev/null 2>&1; then
  if [[ ",${GATE_SKIP:-}," != *",pdffonts,"* ]]; then
    echo "GATE pdffonts: poppler-utils not found; install it or set GATE_SKIP=pdffonts" >&2
    exit 1
  fi
else
  # Column offsets from the end: the type field can contain spaces
  # ("CID Type 0C"), so emb/sub/uni are read relative to NF.
  if pdffonts "${OUT}/${BASE}.pdf" | awk 'NR>2 {
      if ($(NF-4) != "yes" || $(NF-2) != "yes") { print; bad = 1 }
    } END { exit bad }'; then
    :
  else
    echo "FONT EMBEDDING FAILURE in ${OUT}/${BASE}.pdf:"
    pdffonts "${OUT}/${BASE}.pdf"
    exit 1
  fi
fi

# PDF/UA-2 structure gate. Quarto's tagging emits a flat tree without
# heading roles (upstream gap: KOMA + \DocumentMetadata{tagging=on}
# never promotes sections to H1-H6; veraPDF passes by design). This
# checker fails honestly when a UA-2 document lacks heading roles, so
# It fires when the DOCUMENT asks for ua-2 (front matter or metadata
# file override), not when the extension default merely permits it.
# A missing checker fails the render: a UA-2 claim with no
# verification is a false green. GATE_SKIP=pdfua disables the gate
# deliberately.
if grep -qE "pdf-standard.*ua-2" "$FILE" 2>/dev/null \
   || grep -qE "pdf-standard.*ua-2" "${FILE%.qmd}.yml" 2>/dev/null \
   || grep -qE "pdf-standard.*ua-2" "${FILE%.qmd}.yaml" 2>/dev/null; then
  if [ ! -x "$(dirname "$0")/tools/check-pdfua.py" ]; then
    if [[ ",${GATE_SKIP:-}," != *",pdfua,"* ]]; then
      echo "GATE pdfua: tools/check-pdfua.py missing or not executable; fix it or set GATE_SKIP=pdfua" >&2
      exit 1
    fi
  fi
  python3 "$(dirname "$0")/tools/check-pdfua.py" "${OUT}/${BASE}.pdf"
fi

# Controlled-language gate (JSP 101 / ASD-STE100). Fails on hard
# violations (banned words, contractions, American spellings). A
# document opts out with `ste: false` in its front matter. A missing
# checker fails the render for the same false-green reason.
# GATE_SKIP=ste disables the gate deliberately.
if [ ! -f "$(dirname "$0")/tools/check-ste.py" ]; then
  if [[ ",${GATE_SKIP:-}," != *",ste,"* ]]; then
    echo "GATE ste: tools/check-ste.py missing; restore it or set GATE_SKIP=ste" >&2
    exit 1
  fi
fi
python3 "$(dirname "$0")/tools/check-ste.py" "$FILE"

# Tidy the working directory: the gates above have read the LaTeX
# log (LaTeX engine), so move it into the output dir (it is the
# build record) and drop the other intermediates Quarto leaves at
# the root. Typst leaves no log to preserve.
if [ "$ENGINE" = "latex" ] && [ -f "$LOG" ] && [ "$LOG" != "${OUT}/${BASE}.log" ]; then
  mv "$LOG" "${OUT}/${BASE}.log"
fi
rm -f "${BASE}.aux" "${BASE}.toc" "${BASE}.lot" "${BASE}.lof" "${BASE}.out"

if ! command -v qpdf >/dev/null 2>&1; then
  echo "qpdf not found: skipping optimisation and encryption" >&2
  exit 0
fi

# Optimise the distribution copy. Safe for PDF/A: no content, colour
# or font changes; object streams and flate recompression only.
qpdf --object-streams=generate \
     --recompress-flate \
     --compression-level=9 \
     "${OUT}/${BASE}.pdf" "${OUT}/${BASE}-dist.pdf"

# Encrypt the distribution copy when passwords are supplied.
# AES-256 with separate user/owner passwords. Permissions are
# advisory (qpdf manual); a non-empty user password is the real gate.
if [[ -n "${OS_DOC_USER_PASSWORD:-}" ]]; then
  OWNER="${OS_DOC_OWNER_PASSWORD:-$OS_DOC_USER_PASSWORD}"
  qpdf --encrypt \
       --user-password="$OS_DOC_USER_PASSWORD" \
       --owner-password="$OWNER" \
       --bits=256 \
       --print=full \
       --modify=none \
       --extract=n \
       --annotate=n \
       -- \
       "${OUT}/${BASE}-dist.pdf" "${OUT}/${BASE}-enc.pdf"
  echo "Encrypted copy: ${OUT}/${BASE}-enc.pdf"
  qpdf --check --password="$OS_DOC_USER_PASSWORD" "${OUT}/${BASE}-enc.pdf"
fi
