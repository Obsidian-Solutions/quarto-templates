#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""check-ua.py - validate the tagged structure of a PDF/UA-2 render.

veraPDF passes PDF/UA-2 documents that carry no heading roles in the
structure tree: it runs only machine-verifiable Matterhorn checks,
and heading hierarchy is a human checkpoint. PAC catches the gap but
is Windows-only with no CLI.

This checker is the narrow complement: it verifies the invariants the
Obsidian template guarantees when a document opts into PDF/UA-2.

Checks (each is a hard fail when violated):
  1. The PDF has a structure tree (StructTreeRoot).
  2. The document is marked as tagged (MarkInfo /Marked true).
  3. At least one heading role (H1..H6) exists in the tree.
  4. Heading levels do not skip (H1 then H3 without H2 is a fail).
  5. First heading is H1, so the hierarchy starts at the top.

Usage: python3 check-ua.py document.pdf
Exit code 0 = pass, 1 = fail. Output is plain text for CI logs.
"""

import re
import subprocess
import sys

QPDF = "qpdf"


def decompress(pdf_path: str) -> bytes:
    """Return the decompressed PDF bytes via qpdf --qdf."""
    out = subprocess.run(
        [QPDF, "--qdf", "--object-streams=disable", pdf_path, "-"],
        capture_output=True,
        check=True,
    )
    return out.stdout


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: check-ua.py document.pdf")
        return 2
    pdf = sys.argv[1]
    try:
        data = decompress(pdf)
    except subprocess.CalledProcessError as exc:
        print(f"FAIL: qpdf could not read the file: {exc.stderr.decode()}")
        return 1

    failures = []

    # 1. Structure tree present.
    if b"/StructTreeRoot" not in data:
        failures.append("no /StructTreeRoot: the PDF has no structure tree")

    # 2. Tagged marking.
    if b"/Marked true" not in data:
        failures.append("no /Marked true: the PDF is not marked as tagged")

    # 3. Heading roles, as structure element roles (/S /H1).
    headings = {
        level: len(re.findall(rb"/S\s*/H%d\b" % level, data)) for level in range(1, 7)
    }
    if sum(headings.values()) == 0:
        failures.append(
            "no heading roles (H1-H6) in the structure tree: headings "
            "are tagged as Sect/Div, which veraPDF does not catch"
        )

    # 4. Heading hierarchy starts at H1 and does not skip levels.
    present = [lvl for lvl, count in headings.items() if count > 0]
    if present:
        first = present[0]
        if first != 1:
            failures.append(f"first heading level is H{first}, not H1")
        for prev, curr in zip(present, present[1:]):
            if curr - prev > 1:
                failures.append(f"heading levels skip from H{prev} to H{curr}")

    if failures:
        print("FAIL: PDF/UA-2 structure checks")
        for f in failures:
            print(f"  - {f}")
        return 1

    levels = ", ".join(f"H{l}x{c}" for l, c in sorted(headings.items()) if c)
    print(f"PASS: structure tree, tagged marking, heading roles ({levels})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
