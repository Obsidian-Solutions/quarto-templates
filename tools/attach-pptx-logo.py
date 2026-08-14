#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""attach-pptx-logo.py - brand the rendered PPTX with the house logo.

Quarto's PPTX rebuild drops media that the reference document
references (the reference-file logo experiment proved this), so the
logo cannot ship via obsidian-reference.pptx. This tool post-
processes the FINAL rendered pptx instead: nothing rebuilds it
afterward, so the injected logo survives.

It edits the OOXML zip in place:
  - adds ppt/media/obsidian-logo.png
  - registers the image in [Content_Types].xml
  - adds a relationship to the slide master's rels
  - inserts a <p:pic> into the master's spTree (top-right,
    ~2cm wide), before the closing </p:spTree>

The classification marking stays as it is (baked into the
reference-footer); this only adds the brand mark.

Usage:
    attach-pptx-logo.py DECK.pptx [LOGO.png]

Exit 0 on success, 1 on error. Runs after Quarto produces the deck.
"""

import re
import shutil
import sys
import zipfile
from pathlib import Path

REL_ID = "rIdObsidianLogo"
MASTER_PATH = "ppt/slideMasters/slideMaster1.xml"
MASTER_RELS = "ppt/slideMasters/_rels/slideMaster1.xml.rels"
MEDIA_PATH = "ppt/media/obsidian-logo.png"
CONTENT_TYPES = "[Content_Types].xml"
MARGIN_EMU = 457200  # 0.5 inch


def slide_width_emu(names: list[str], read) -> int:
    """The slide width in EMU from ppt/presentation.xml (default 4:3)."""
    if "ppt/presentation.xml" not in names:
        return 9144000
    m = re.search(
        r'<p:sldSz[^>]*cx="(\d+)"', read("ppt/presentation.xml").decode("utf-8")
    )
    return int(m.group(1)) if m else 9144000


def pic_xml(
    rid: str, width_emu: int, cx_emu: int = 720000, cy_emu: int = 180000
) -> str:
    """A p:pic element anchored top-right within the slide, ~2cm wide."""
    x = width_emu - cx_emu - MARGIN_EMU
    return (
        "<p:pic>"
        "<p:nvPicPr>"
        '<p:cNvPr id="9999" name="Obsidian Solutions logo"/>'
        '<p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr>'
        "<p:nvPr/>"
        "</p:nvPicPr>"
        '<p:blipFill><a:blip r:embed="%s"/><a:stretch><a:fillRect/></a:stretch></p:blipFill>'
        "<p:spPr>"
        "<a:xfrm>"
        '<a:off x="%d" y="%d"/>'
        '<a:ext cx="%d" cy="%d"/>'
        "</a:xfrm>"
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>'
        "</p:spPr>"
        "</p:pic>" % (rid, x, MARGIN_EMU, cx_emu, cy_emu)
    )


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        return 1
    deck = Path(sys.argv[1])
    logo = (
        Path(sys.argv[2])
        if len(sys.argv) > 2
        else Path(__file__).resolve().parent.parent
        / "_extensions"
        / "obsidian"
        / "assets"
        / "obsidian-logo.png"
    )
    if not deck.exists():
        print("attach-pptx-logo: deck not found: %s" % deck, file=sys.stderr)
        return 1
    if not logo.exists():
        print("attach-pptx-logo: logo not found: %s" % logo, file=sys.stderr)
        return 1

    tmp = deck.with_suffix(".logo.pptx")
    with (
        zipfile.ZipFile(deck) as zin,
        zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as zout,
    ):
        names = zin.namelist()
        if MASTER_PATH not in names:
            print("attach-pptx-logo: no slide master in %s" % deck, file=sys.stderr)
            return 1
        width = slide_width_emu(names, zin.read)

        for item in zin.infolist():
            data = zin.read(item.filename)
            if item.filename == MASTER_PATH:
                text = data.decode("utf-8")
                if REL_ID in text:
                    print("attach-pptx-logo: logo already present", file=sys.stderr)
                    return 1
                if not re.search(r"</p:spTree>", text):
                    print("attach-pptx-logo: spTree not found", file=sys.stderr)
                    return 1
                # Master may lack the r: prefix declaration for blip
                # embeds; it is already declared (r: is on the root).
                text = text.replace(
                    "</p:spTree>", pic_xml(REL_ID, width) + "</p:spTree>", 1
                )
                zout.writestr(item, text)
            elif item.filename == MASTER_RELS:
                text = data.decode("utf-8")
                if 'Id="%s"' % REL_ID not in text:
                    rel = (
                        '<Relationship Id="%s" '
                        'Type="http://schemas.openxmlformats.org/'
                        'officeDocument/2006/relationships/image" '
                        'Target="../media/obsidian-logo.png"/>' % REL_ID
                    )
                    text = text.replace("</Relationships>", rel + "</Relationships>", 1)
                zout.writestr(item, text)
            elif item.filename == CONTENT_TYPES:
                text = data.decode("utf-8")
                if 'Extension="png"' not in text:
                    ext = '<Default Extension="png" ContentType="image/png"/>'
                    text = text.replace("</Types>", ext + "</Types>", 1)
                zout.writestr(item, text)
            else:
                zout.writestr(item, data)
        zout.write(logo, MEDIA_PATH)

    shutil.move(tmp, deck)
    print("branded %s with %s" % (deck, logo.name))
    return 0


if __name__ == "__main__":
    sys.exit(main())
