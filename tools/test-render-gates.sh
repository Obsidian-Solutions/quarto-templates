#!/bin/bash
# SPDX-License-Identifier: MIT
# Regression test for the render.sh verification-gate tooling policy:
# a gate whose tool is missing must fail the render (exit 1), and
# GATE_SKIP must be able to disable that failure deliberately.
# Extracts the three gate blocks verbatim from render.sh, runs them
# in a sandbox with tools present/absent.
set -u
FAIL=0
ok()   { echo "PASS $1"; }
bad()  { echo "FAIL $1: expected exit $2, got $3"; FAIL=1; }
expect() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "$2" "$3"; fi }

RENDER_SH="$(dirname "$0")/../render.sh"
SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
mockbin="$SB/mockbin"
mkdir -p "$SB/tools" "$SB/_extensions/obsidian" "$SB/_output" "$mockbin"

# minimal PATH: real tools we need, symlinked, plus mocks
for t in awk grep dirname cat sed head tail; do
  ln -s "$(command -v $t)" "$mockbin/$t"
done
cat > "$mockbin/python3" <<'EOF'
#!/bin/bash
# MOCK_PY_EXIT lets a case simulate the checker's verdict: 0 (pass)
# or 1 (fail, the documented heading-role-gap outcome).
exit "${MOCK_PY_EXIT:-0}"
EOF
chmod +x "$mockbin/python3"

# fragment files must live inside the sandbox (dirname "$0" resolves there).
# Extract each gate block by its leading comment marker, so the test
# survives line shifts in render.sh.
awk '/^# Font-embedding pre-flight/{f=1} f{print} f && /^fi$/{exit}' "$RENDER_SH" > "$SB/frag-pdffonts.sh"
awk '/^# PDF\/UA-2 structure gate/{f=1} f{print} f && /^fi$/{exit}' "$RENDER_SH" > "$SB/frag-pdfua.sh"
awk '/^# Controlled-language gate/{f=1} f{print} f && /^fi$/{exit}' "$RENDER_SH" > "$SB/frag-ste.sh"

export OUT=_output BASE=template FILE=template.qmd

# ---- pdffonts gate (command -v) ----
# A1: absent -> must fail
PATH="$mockbin" /bin/bash "$SB/frag-pdffonts.sh" >/dev/null 2>&1
expect "pdffonts absent -> fail(1)" 1 "$?"
# A2: absent + GATE_SKIP -> must pass
PATH="$mockbin" GATE_SKIP=pdffonts /bin/bash "$SB/frag-pdffonts.sh" >/dev/null 2>&1
expect "pdffonts absent+GATE_SKIP -> pass(0)" 0 "$?"
# A3: present -> runs, passes
cat > "$mockbin/pdffonts" <<'EOF'
#!/bin/bash
echo "name emb uni"; echo "F yes yes"
EOF
chmod +x "$mockbin/pdffonts"
PATH="$mockbin" /bin/bash "$SB/frag-pdffonts.sh" >/dev/null 2>&1
expect "pdffonts present -> pass(0)" 0 "$?"
rm -f "$mockbin/pdffonts"

# ---- pdfua gate (file -x check on tools/check-pdfua.py) ----
# The gate fires only when the DOCUMENT declares ua-2 (front matter
# or metadata file), not when the extension default merely permits
# it. The sandbox document must declare it, or the gate never fires
# and the test passes vacuously (finding N3). Run the fragment from
# the sandbox so $FILE resolves to the declaring document.
printf -- '---\nformat:\n  obsidian-pdf:\n    pdf-standard: [a-4f, ua-2]\n---\n' > "$SB/template.qmd"
# B1: checker present -> python3 mock runs, pass
touch "$SB/tools/check-pdfua.py"; chmod +x "$SB/tools/check-pdfua.py"
(cd "$SB" && PATH="$mockbin" /bin/bash "$SB/frag-pdfua.sh") >/dev/null 2>&1
expect "pdfua checker present -> pass(0)" 0 "$?"
# B1b: checker present but fails (the documented heading-role gap: a
# LaTeX UA-2 render has no heading roles, so check-pdfua.py exits 1)
# -> the gate must fail, matching the README expectation. This is the
# non-vacuous assertion: it proves the gate fired on the declaration.
(cd "$SB" && PATH="$mockbin" MOCK_PY_EXIT=1 /bin/bash "$SB/frag-pdfua.sh") >/dev/null 2>&1
expect "pdfua checker fails on heading-role gap -> fail(1)" 1 "$?"
# B2: checker absent -> fail
rm "$SB/tools/check-pdfua.py"
(cd "$SB" && PATH="$mockbin" /bin/bash "$SB/frag-pdfua.sh") >/dev/null 2>&1
expect "pdfua checker absent -> fail(1)" 1 "$?"
# B3: absent + GATE_SKIP -> pass
(cd "$SB" && PATH="$mockbin" GATE_SKIP=pdfua /bin/bash "$SB/frag-pdfua.sh") >/dev/null 2>&1
expect "pdfua absent+GATE_SKIP -> pass(0)" 0 "$?"
rm -f "$SB/template.qmd"

# ---- ste gate (file -f check) ----
touch "$SB/tools/check-ste.py"
PATH="$mockbin" /bin/bash "$SB/frag-ste.sh" >/dev/null 2>&1
expect "ste checker present -> pass(0)" 0 "$?"
rm "$SB/tools/check-ste.py"
PATH="$mockbin" /bin/bash "$SB/frag-ste.sh" >/dev/null 2>&1
expect "ste checker absent -> fail(1)" 1 "$?"
PATH="$mockbin" GATE_SKIP=ste /bin/bash "$SB/frag-ste.sh" >/dev/null 2>&1
expect "ste absent+GATE_SKIP -> pass(0)" 0 "$?"

exit $FAIL