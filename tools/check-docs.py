#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""check-docs.py - verify the documentation matches the implementation.

The reference.md Format and verification-gates tables are the user
facing contract for this template; a stale table is a trap. This
script checks the things that drift:

  * every format contributed by _extension.yml appears in the
    reference.md Formats table (and nothing extra is listed)
  * every GATE_SKIP name render.sh honors appears in the
    reference.md verification-gates section
  * the example templates listed in README.md exist on disk

Run in CI with:  python3 tools/check-docs.py
Exit 1 with a list of mismatches when anything drifts.
"""

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent


def fail(msg):
    print("check-docs: %s" % msg, file=sys.stderr)


def formats_from_extension(ext_yml: str) -> set:
    """Names of the formats the extension contributes."""
    m = re.search(r"^[ \t]*formats:\s*$", ext_yml, re.M)
    if not m:
        return set()
    # The formats block lists each format as a key at one deeper
    # indent than `formats:` itself.
    block = ext_yml[m.end() :]
    outer = len(m.group(0)) - len(m.group(0).lstrip())
    indent = None
    names = set()
    for line in block.splitlines():
        if not line.strip() or line.strip().startswith("#"):
            continue
        lead = len(line) - len(line.lstrip())
        if indent is None:
            if lead <= outer:
                break
            indent = lead
        # A line shallower than the format keys ends the block; a
        # deeper line is nested content of the current format.
        if lead < indent:
            break
        if lead == indent:
            key = line.strip().split(":", 1)[0].strip()
            if key:
                names.add(key)
    return names


def formats_from_reference(ref_md: str) -> set:
    """Names in the reference.md Formats table rows."""
    m = re.search(r"## Formats\n(.*?)\n## ", ref_md, re.S)
    if not m:
        return set()
    rows = set()
    for line in m.group(1).splitlines():
        if line.strip().startswith("| `obsidian-"):
            name = line.split("`")[1]
            rows.add(name)
    return rows


def gates_from_render_sh(render_sh: str) -> set:
    """GATE_SKIP names render.sh honors."""
    return set(re.findall(r"GATE_SKIP=(\w+)", render_sh))


def gates_from_reference(ref_md: str) -> set:
    """GATE_SKIP names the reference.md documents.

    The names appear both as GATE_SKIP=name literals and inside a
    comma-separated list like `provenance,pdffonts,pdfua,ste`. Accept
    both forms.
    """
    gates = set(re.findall(r"GATE_SKIP=(\w+)", ref_md))
    for m in re.finditer(r"comma-separated:\s*`([^`]+)`", ref_md):
        for name in m.group(1).split(","):
            name = name.strip()
            if name:
                gates.add(name)
    return gates


def main() -> int:
    ext = (REPO / "_extensions" / "obsidian" / "_extension.yml").read_text()
    ref = (REPO / "docs" / "reference.md").read_text()
    render = (REPO / "render.sh").read_text()
    readme = (REPO / "README.md").read_text()

    bad = 0

    fmt_ext = {"obsidian-" + k for k in formats_from_extension(ext)}
    fmt_ref = formats_from_reference(ref)
    if fmt_ext and fmt_ref:
        missing = fmt_ext - fmt_ref
        extra = fmt_ref - fmt_ext
        for f in sorted(missing):
            fail("format %s in _extension.yml but not in the Formats table" % f)
            bad += 1
        for f in sorted(extra):
            fail("format %s listed in the Formats table but not contributed" % f)
            bad += 1
    else:
        fail("could not parse the formats tables (regex changed?)")
        bad += 1

    gates_impl = gates_from_render_sh(render)
    gates_doc = gates_from_reference(ref)
    for g in sorted(gates_impl - gates_doc):
        fail("GATE_SKIP=%s honored by render.sh but not documented" % g)
        bad += 1

    # README example table vs files on disk.
    for m in re.finditer(r"examples/(template[-\w]*\.qmd)", readme):
        p = REPO / "examples" / m.group(1)
        if not p.exists():
            fail("README lists %s but the file does not exist" % m.group(1))
            bad += 1

    if bad:
        fail("%d mismatch(es); update the docs or the code, not both" % bad)
        return 1
    print("check-docs: OK (formats, gates, examples all agree)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
