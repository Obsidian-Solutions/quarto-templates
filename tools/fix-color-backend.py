#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""fix-color-backend.py - patch leaked expl3 color commands in content streams.

TeX Live 2026's xcolor-patches-tmp-ltx.sty v0.97c can leak the LaTeX3
internal \\__color_backend_raw_rgb:n literally into PDF content streams
instead of expanding to the PDF `rg` operator. This breaks PDF/A-4f
validation (veraPDF rule 6.2.2: non-standard operators).

This tool scans every page's content streams and replaces the literal
expl3 command with the correct PDF operator.

Usage:
    fix-color-backend.py INPUT.pdf

Writes INPUT.pdf in place. Exit 0 on success, 1 on error.
"""

import re
import sys
from pathlib import Path

import pikepdf

# Match the leaked expl3 command and its RGB arguments.
# The literal string in the content stream is:
#   \\__color_backend_raw_rgb:n {R G B}
# where R, G, B are decimal floats between 0 and 1.
_LEAKED_PATTERN = re.compile(
    rb"\\__color_backend_raw_rgb:n\s*\{(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\}"
)


def fix_stream(data: bytes) -> tuple[bytes, int]:
    """Replace leaked expl3 color commands with PDF rg operator."""
    count = 0

    def _replace(m: re.Match) -> bytes:
        nonlocal count
        count += 1
        r, g, b = m.group(1), m.group(2), m.group(3)
        return rb"%s %s %s rg" % (r, g, b)

    result = _LEAKED_PATTERN.sub(_replace, data)
    return result, count


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        return 1
    pdf_path = Path(sys.argv[1])
    if not pdf_path.exists():
        print("fix-color-backend: not found: %s" % pdf_path, file=sys.stderr)
        return 1

    total = 0
    with pikepdf.open(pdf_path, allow_overwriting_input=True) as pdf:
        for page in pdf.pages:
            try:
                contents = page.get("/Contents")
            except KeyError:
                continue
            streams = (
                [contents]
                if isinstance(contents, pikepdf.Stream)
                else list(contents)
                if contents
                else []
            )
            for stream_obj in streams:
                data = stream_obj.read_bytes()
                fixed, count = fix_stream(data)
                if count:
                    stream_obj.write(fixed)
                    total += count
        pdf.save(pdf_path)

    if total:
        print("fixed %d leaked color command(s) in %s" % (total, pdf_path))
    else:
        print("no leaked color commands found in %s" % pdf_path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
