#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Unit tests for the token generator and PDF/PPTX tools.

Run with:  python3 -m unittest tools/test_tools.py
or:        pytest tools/test_tools.py
"""

import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
REPO = TOOLS.parent

# Load the tool modules under test as plain modules (no package import
# side effects; each is a stdlib-only script).
import importlib.util


def _load(name):
    spec = importlib.util.spec_from_file_location(name, TOOLS / (name + ".py"))
    assert spec and spec.loader, "cannot load %s" % name
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


tokens_mod = _load("tokens")

# The provenance tool needs pikepdf. Detect it by import in the
# current interpreter: the tests skip only when the import genuinely
# fails, so CI runs them whenever pikepdf is installed (no hardcoded
# venv path).
try:
    import pikepdf  # noqa: F401

    PIKEPDF_PY = sys.executable
except ImportError:
    PIKEPDF_PY = None


def run(*args, python=sys.executable, cwd=None):
    return subprocess.run(
        [python, *args], capture_output=True, text=True, cwd=cwd or REPO
    )


class TestTokens(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp)
        self.brand = REPO / "_extensions" / "obsidian" / "brand.yml"
        self.mod = tokens_mod

    def test_parse_sections(self):
        """brand.yml parses into color/type/spacing with the house roles."""
        sec = self.mod.parse_brand(self.brand)
        self.assertIn("color", sec)
        self.assertIn("type", sec)
        self.assertIn("spacing", sec)
        c = sec["color"]
        for role in ("primary", "secondary", "border", "surface", "link"):
            self.assertIn(role, c)
        self.assertEqual(c["primary"], "#121212")

    def test_emit_tex_aliases(self):
        """tokens.tex defines the legacy house names via the semantic roles."""
        sec = self.mod.parse_brand(self.brand)
        tex = self.mod.emit_tex(sec["color"], self.mod.LEGACY_ALIASES)
        # primary #121212 -> obsidian; secondary #484949 -> obsidianl
        self.assertIn(r"\definecolor{obsidian}{HTML}{121212}", tex)
        self.assertIn(r"\definecolor{obsidianl}{HTML}{484949}", tex)
        self.assertIn(r"\definecolor{ruled}{HTML}{CECECE}", tex)
        self.assertIn(r"\definecolor{cream}{HTML}{F3F3F3}", tex)

    def test_generate_is_idempotent(self):
        """Re-running the generator produces byte-identical files."""
        r1 = run(str(TOOLS / "tokens.py"), str(self.brand), self.tmp)
        self.assertEqual(r1.returncode, 0, r1.stderr)
        tex1 = (Path(self.tmp) / "tokens.tex").read_bytes()
        scss1 = (Path(self.tmp) / "tokens.scss").read_bytes()
        r2 = run(str(TOOLS / "tokens.py"), str(self.brand), self.tmp)
        self.assertEqual(r2.returncode, 0, r2.stderr)
        self.assertEqual(tex1, (Path(self.tmp) / "tokens.tex").read_bytes())
        self.assertEqual(scss1, (Path(self.tmp) / "tokens.scss").read_bytes())

    def test_check_passes_on_clean_tree(self):
        """--check against the real theme.scss must pass."""
        r = run(
            str(TOOLS / "tokens.py"),
            "--check",
            str(self.brand),
            str(REPO / "_extensions" / "obsidian"),
        )
        self.assertEqual(r.returncode, 0, r.stderr)

    def test_check_detects_drift(self):
        """--check fails when theme.scss disagrees with brand.yml."""
        tmp_ext = Path(self.tmp) / "ext"
        shutil.copytree(REPO / "_extensions" / "obsidian", tmp_ext)
        theme = tmp_ext / "theme.scss"
        s = theme.read_text()
        theme.write_text(
            s.replace("$theme-obsidian: #121212", "$theme-obsidian: #111111")
        )
        r = run(str(TOOLS / "tokens.py"), "--check", str(self.brand), str(tmp_ext))
        self.assertEqual(r.returncode, 1)


class TestAttachProvenance(unittest.TestCase):
    """Requires pikepdf. Skipped when absent."""

    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp)

    def _fixture_pdf(self):
        """Render a tiny typst document to get a real PDF fixture.

        Quarto renders into the project directory; build a temp
        project with the extension symlinked so the run is hermetic
        and the output lands at a known path.
        """
        proj = Path(self.tmp) / "proj"
        (proj / "_extensions").mkdir(parents=True)
        # A real copy, not a symlink: Quarto resolves @preview
        # packages from the extension dir and a symlink breaks its
        # typst package resolution.
        shutil.copytree(
            REPO / "_extensions" / "obsidian",
            proj / "_extensions" / "obsidian",
        )
        src = proj / "doc.qmd"
        src.write_text(
            "---\n"
            "title: Fixture\n"
            "author: Obsidian Solutions\n"
            "format:\n"
            "  obsidian-typst:\n"
            "    pdf-standard: a-4f\n"
            "---\n\n"
            "# Heading\n\nBody.\n"
        )
        out = proj / "doc.pdf"
        r = subprocess.run(
            ["quarto", "render", str(src)],
            capture_output=True,
            text=True,
            cwd=proj,
        )
        if r.returncode != 0 or not out.exists():
            self.skipTest("could not render the typst fixture: %s" % r.stderr[-300:])
        return out

    @unittest.skipUnless(PIKEPDF_PY, "pikepdf not importable")
    def test_attach_and_afrelationship(self):
        import json

        pdf = self._fixture_pdf()
        src = REPO / "examples" / "template-typst.qmd"
        r = run(
            str(TOOLS / "attach-provenance.py"),
            str(pdf),
            str(src),
            python=str(PIKEPDF_PY),
        )
        self.assertEqual(r.returncode, 0, r.stderr)

        # Inspect with pikepdf: attachment present, AFRelationship set.
        code = (
            "import pikepdf, json, sys\n"
            "pdf = pikepdf.open(sys.argv[1])\n"
            "names = list(pdf.attachments)\n"
            "spec = pdf.attachments[names[0]].obj\n"
            "print(json.dumps({\n"
            "  'names': names,\n"
            "  'af': str(spec.get('/AFRelationship')),\n"
            "  'sub': str(spec['/EF']['/F'].get('/Subtype')),\n"
            "}))\n"
        )
        r2 = run("-c", code, str(pdf), python=str(PIKEPDF_PY))
        self.assertEqual(r2.returncode, 0, r2.stderr)
        info = json.loads(r2.stdout.strip().splitlines()[-1])
        self.assertIn("template-typst.qmd", info["names"])
        self.assertEqual(info["af"], "/Source")
        self.assertIn("markdown", info["sub"])


class TestAttachPptxLogo(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp)

    def _fixture_pptx(self):
        """Build a minimal valid pptx (presentation + slide master)."""
        import zipfile

        def _w(path, data):
            (Path(self.tmp) / path).parent.mkdir(parents=True, exist_ok=True)
            (Path(self.tmp) / path).write_bytes(data)

        _w(
            "[Content_Types].xml",
            b"""<?xml version="1.0"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
<Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>
</Types>""",
        )
        _w(
            "_rels/.rels",
            b"""<?xml version="1.0"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
</Relationships>""",
        )
        _w(
            "ppt/presentation.xml",
            b"""<?xml version="1.0"?>
<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
 sldMasterIdLst=""><p:sldMasterId id="1" r:id="rId1"/><p:sldSz cx="9144000" cy="5143500"/></p:presentation>""",
        )
        _w(
            "ppt/_rels/presentation.xml.rels",
            b"""<?xml version="1.0"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>
</Relationships>""",
        )
        _w(
            "ppt/slideMasters/slideMaster1.xml",
            b"""<?xml version="1.0"?>
<p:sldMaster xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/></p:spTree></p:cSld></p:sldMaster>""",
        )
        _w(
            "ppt/slideMasters/_rels/slideMaster1.xml.rels",
            b"""<?xml version="1.0"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
</Relationships>""",
        )

        pptx = Path(self.tmp) / "fixture.pptx"
        with zipfile.ZipFile(pptx, "w", zipfile.ZIP_DEFLATED) as z:
            for p in sorted((Path(self.tmp) / "").rglob("*")):
                if p.is_file() and p != pptx:
                    z.write(p, p.relative_to(self.tmp))
        return pptx

    def test_inject_logo(self):
        import zipfile

        pptx = self._fixture_pptx()
        logo = REPO / "_extensions" / "obsidian" / "assets" / "obsidian-logo.png"
        r = run(str(TOOLS / "attach-pptx-logo.py"), str(pptx), str(logo))
        self.assertEqual(r.returncode, 0, r.stderr)
        with zipfile.ZipFile(pptx) as z:
            names = z.namelist()
            self.assertIn("ppt/media/obsidian-logo.png", names)
            master_rels = z.read(
                "ppt/slideMasters/_rels/slideMaster1.xml.rels"
            ).decode()
            self.assertIn("rIdObsidianLogo", master_rels)
            master = z.read("ppt/slideMasters/slideMaster1.xml").decode()
            self.assertIn("<p:pic>", master)


if __name__ == "__main__":
    unittest.main()
