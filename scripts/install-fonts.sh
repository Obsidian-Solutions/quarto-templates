#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Install the Montserrat TTFs the template needs.
#
# The fonts come from a pinned upstream commit with a SHA-256 check
# on every download, so a changed or tampered file fails the CI
# loudly instead of silently substituting. The workflows call this
# script; update the pin here in one place.
#
# Montserrat is SIL Open Font License 1.1 (Copyright Julieta
# Ulanovsky); see NOTICE.
set -euo pipefail

MONS_COMMIT="555facfb2a18c72c3c0380f0d9c0f060453a9058"
BASE="https://raw.githubusercontent.com/JulietaUla/Montserrat/${MONS_COMMIT}/fonts/ttf"
mkdir -p ~/.fonts

install_font() {
  local name="$1" want="$2"
  curl -sL "${BASE}/${name}.ttf" -o "${HOME}/.fonts/${name}.ttf"
  local got
  got=$(sha256sum "${HOME}/.fonts/${name}.ttf" | cut -d' ' -f1)
  if [ "$got" != "$want" ]; then
    echo "FONT CHECKSUM MISMATCH for ${name}: got ${got}, want ${want}" >&2
    echo "Update the pin in scripts/install-fonts.sh (and NOTICE) only after verifying the upstream change." >&2
    exit 1
  fi
  echo "verified ${name} (${got})"
}

install_font Montserrat-Regular 3e8abe50c44c82e2242e97d1ec8c0d385c4890cdc50447bcdb8605c81a38cfb2
install_font Montserrat-Bold bc6e854971cea46b463be6f9eef4d9cd52f51cfc1fc0dd90c9d3e6483dc0ec61
install_font Montserrat-SemiBold b4e1563393d73fdff491a869441245aef31add2ec03d9c97a6dae4de07c52fd0

fc-cache -f ~/.fonts >/dev/null 2>&1
echo "fonts installed"
