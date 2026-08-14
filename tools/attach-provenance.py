#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""attach-provenance.py - embed source files into a PDF/A-4f archive.

PDF/A-4f (ISO 19005-4) permits embedded files, but every embedded
file's specification dictionary must carry an AFRelationship key
(ISO 32000-2, 7.11.3) and its stream a valid MIME Subtype (6.9).
qpdf's --add-attachment writes neither, so this tool uses pikepdf,
which sets AFRelationship directly via AttachedFileSpec.

Usage:
    attach-provenance.py INPUT.pdf SOURCE.qmd [SOURCE2 ...]

Writes INPUT.pdf in place. Each source is embedded with key
"Source", relationship "Source", and a markdown MIME subtype.
Exit 0 on success, 1 on error.
"""

import sys
from pathlib import Path

import pikepdf
from pikepdf import AttachedFileSpec, Name

MIME = Name("/text/markdown")


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__, file=sys.stderr)
        return 1
    pdf_path = Path(sys.argv[1])
    sources = [Path(a) for a in sys.argv[2:]]
    if not pdf_path.exists():
        print("attach-provenance: input PDF not found: %s" % pdf_path, file=sys.stderr)
        return 1

    with pikepdf.open(pdf_path, allow_overwriting_input=True) as pdf:
        for src in sources:
            if not src.exists():
                print("attach-provenance: source not found: %s" % src, file=sys.stderr)
                return 1
            spec = AttachedFileSpec.from_filepath(
                pdf,
                src,
                description="Source document: %s" % src.name,
                relationship=Name.Source,
            )
            # PDF/A-4f clause 6.9: the embedded stream needs a valid
            # MIME Subtype. pikepdf guesses from the filename; .qmd is
            # unknown, so force markdown.
            ef = spec.obj["/EF"]
            for k in ("/F", "/UF"):
                ef[k]["/Subtype"] = MIME
            pdf.attachments[src.name] = spec
        pdf.save(pdf_path)

    print("attached %d source(s) to %s" % (len(sources), pdf_path))
    return 0


if __name__ == "__main__":
    sys.exit(main())
