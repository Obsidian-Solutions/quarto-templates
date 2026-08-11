#!/usr/bin/env bash
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
set -euo pipefail

FILE="${1:-example.qmd}"
HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
DATE=$(date +%Y-%m-%d)
BASE="${FILE%.qmd}"

quarto render "$FILE" -M baseline="$HASH, $DATE"

if ! command -v qpdf >/dev/null 2>&1; then
  echo "qpdf not found: skipping optimisation and encryption" >&2
  exit 0
fi

# Optimise the distribution copy. Safe for PDF/A: no content, colour
# or font changes; object streams and flate recompression only.
qpdf --object-streams=generate \
     --recompress-flate \
     --compression-level=9 \
     "${BASE}.pdf" "${BASE}-dist.pdf"

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
       "${BASE}-dist.pdf" "${BASE}-enc.pdf"
  echo "Encrypted copy: ${BASE}-enc.pdf"
  qpdf --check --password="$OS_DOC_USER_PASSWORD" "${BASE}-enc.pdf"
fi
