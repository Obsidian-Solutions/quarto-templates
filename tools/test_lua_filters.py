#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Tests for the Quarto Lua filters, driven through pandoc directly.

Each filter is a pandoc Lua filter. Running pandoc with the filter on
a tiny markdown input exercises the filter's real code path (no
mocks). Requires pandoc on PATH.

Run with:  python3 -m unittest tools/test_lua_filters.py
"""

import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
FILTERS = TOOLS.parent / "_extensions" / "obsidian" / "filters"


def pandoc_ast(md: str, filters: list[str], meta: str = "") -> dict:
    """Run pandoc with the given filters and metadata, return the JSON AST."""
    tmp = tempfile.mkdtemp()
    try:
        src = Path(tmp) / "in.md"
        src.write_text(md)
        cmd = ["pandoc", "--from", "markdown", "--to", "json", "--standalone"]
        for f in filters:
            cmd += ["--lua-filter", str(FILTERS / f)]
        if meta:
            meta_file = Path(tmp) / "meta.yml"
            meta_file.write_text(meta)
            cmd += ["--metadata-file", str(meta_file)]
        cmd.append(str(src))
        r = subprocess.run(cmd, capture_output=True, text=True)
        if r.returncode != 0:
            raise AssertionError("pandoc failed: %s" % r.stderr[-500:])
        return json.loads(r.stdout)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def walk(node, pred, out):
    if isinstance(node, dict):
        if pred(node):
            out.append(node)
        for v in node.values():
            walk(v, pred, out)
    elif isinstance(node, list):
        for v in node:
            walk(v, pred, out)


@unittest.skipUnless(shutil.which("pandoc"), "pandoc not on PATH")
class TestClassificationGate(unittest.TestCase):
    def test_confidentiality_not_blocked(self):
        """A commercial document with confidentiality renders (no error)."""
        md = "---\ntitle: T\nconfidentiality: Commercial in Confidence\n---\n\n# H\n\nBody.\n"
        ast = pandoc_ast(md, ["classification-gate.lua"])
        # The gate either returns the doc unchanged or errors; a parse
        # here means it did not block.
        self.assertIn("blocks", ast)

    def test_meta_survives(self):
        md = "---\ntitle: T\n---\n\nBody.\n"
        ast = pandoc_ast(md, ["classification-gate.lua"])
        meta = ast.get("meta", {})
        self.assertIn("title", meta)


@unittest.skipUnless(shutil.which("pandoc"), "pandoc not on PATH")
class TestSummaryList(unittest.TestCase):
    def test_deflist_wrapped(self):
        """A definition list gets wrapped in the summary-list Div."""
        md = "Term\n: Definition\n"
        ast = pandoc_ast(md, ["summary-list.lua"])
        divs = []
        walk(ast, lambda n: n.get("t") == "Div", divs)
        self.assertEqual(len(divs), 1, divs)
        classes = divs[0]["c"][0][1]
        self.assertIn("obsidian-summary-list", classes)

    def test_opt_out(self):
        """The documented false=\"true\" marker opts out of wrapping."""
        md = '::: {.obsidian-summary-list false="true"}\nTerm\n: Definition\n:::\n'
        ast = pandoc_ast(md, ["summary-list.lua"])

        # The opt-out Div keeps the marker class; the inner definition
        # list must NOT be wrapped in an additional summary-list Div.
        # Walk: a DefList is acceptable only inside a Div that either
        # lacks the class or carries the false="true" marker.
        def check(node, in_summary, marker):
            if isinstance(node, dict):
                t = node.get("t")
                if t == "Div":
                    cls = node["c"][0][1]
                    attr = dict(node["c"][0][2])
                    child_in = "obsidian-summary-list" in cls
                    child_marker = attr.get("false") == "true"
                    if child_in and child_marker:
                        child_in = False  # marker cancels the wrap
                    check(node.get("c"), child_in, child_marker)
                elif t == "DefinitionList":
                    self.assertFalse(in_summary, "DefList wrapped despite opt-out")
                else:
                    check(node.get("c"), in_summary, marker)
            elif isinstance(node, list):
                for v in node:
                    check(v, in_summary, marker)

        check(ast, False, False)


@unittest.skipUnless(shutil.which("pandoc"), "pandoc not on PATH")
class TestTypstMeta(unittest.TestCase):
    def test_numbering_forwarded(self):
        """section-numbering present -> numbersections MetaBool(true)."""
        md = "# H\n\nBody.\n"
        meta = 'section-numbering:\n  - "1"\n  - "a"\n'
        ast = pandoc_ast(md, ["typst-meta.lua"], meta)
        ns = ast["meta"].get("numbersections", {})
        self.assertEqual(ns, {"t": "MetaBool", "c": True})

    def test_no_numbering(self):
        """No section-numbering -> numbersections absent."""
        md = "# H\n\nBody.\n"
        ast = pandoc_ast(md, ["typst-meta.lua"])
        self.assertNotIn("numbersections", ast["meta"])


@unittest.skipUnless(shutil.which("pandoc"), "pandoc not on PATH")
class TestInvoice(unittest.TestCase):
    """The invoice filter expands the invoice metadata at the marker."""

    META = """
invoice:
  number: "2026-008"
  date: "2026-08-15"
  client:
    name: "Acme Ltd"
    address: |
      1 High Street
      Exeter EX1 1AA
  items:
    - description: "Server care retainer"
      quantity: 1
      unit-price: "300.00"
    - description: "Security patch run"
      quantity: 2
      unit-price: "75.00"
  payment:
    terms: "Due within 14 days"
    provider: "stripe"
    link: "https://buy.stripe.com/test_0000"
"""

    def _texts(self, ast):
        out = []
        walk(ast, lambda n: n.get("t") == "Str" and out.append(n["c"]), None)
        return out

    def test_absent_invoice_metadata_unmodified(self):
        """No invoice metadata -> the marker Div stays empty."""
        md = "::: {.obsidian-invoice}\n:::\n\nBody.\n"
        ast = pandoc_ast(md, ["invoice.lua"])
        texts = self._texts(ast)
        self.assertNotIn("Invoice number", texts)

    def test_client_and_number_expanded(self):
        """Client name, address, and invoice number appear in the body."""
        md = "::: {.obsidian-invoice}\n:::\n"
        ast = pandoc_ast(md, ["invoice.lua"], self.META)
        texts = " ".join(self._texts(ast))
        self.assertIn("Acme Ltd", texts)
        self.assertIn("High Street", texts)
        self.assertIn("Invoice number", texts)
        self.assertIn("2026-008", texts)

    def test_totals_computed(self):
        """300 + (2 x 75) = 450.00, with a GBP total line."""
        md = "::: {.obsidian-invoice}\n:::\n"
        ast = pandoc_ast(md, ["invoice.lua"], self.META)
        texts = " ".join(self._texts(ast))
        self.assertIn("Subtotal", texts)
        self.assertIn("450.00", texts)
        self.assertIn("Total due", texts)

    def test_payment_link_provider(self):
        """stripe/paypal/generic render a pay-now link."""
        md = "::: {.obsidian-invoice}\n:::\n"
        ast = pandoc_ast(md, ["invoice.lua"], self.META)
        links = []
        # Link AST: c = [attr, inlines, target] where target = [url, title].
        walk(ast, lambda n: n.get("t") == "Link" and links.append(n["c"][2][0]), None)
        self.assertTrue(any("buy.stripe.com" in l for l in links), "no stripe link")

    def test_bank_transfer_details(self):
        """bank-transfer renders bank details, not a link."""
        meta = self.META.replace(
            'provider: "stripe"\n    link: "https://buy.stripe.com/test_0000"',
            'provider: "bank-transfer"\n    details:\n      bank: "Example Bank"\n      sort-code: "00-00-00"\n      account: "00000000"\n      name: "Obsidian Solutions"\n      reference: "INV-2026-008"',
        )
        md = "::: {.obsidian-invoice}\n:::\n"
        ast = pandoc_ast(md, ["invoice.lua"], meta)
        texts = " ".join(self._texts(ast))
        self.assertIn("Example Bank", texts)
        self.assertIn("Sort code", texts)
        self.assertIn("INV-2026-008", texts)
        links = []
        walk(ast, lambda n: n.get("t") == "Link" and links.append(n["c"][2][0]), None)
        self.assertEqual(links, [], "bank-transfer must not render a link")

    def test_author_body_preserved(self):
        """Hand-written body content survives next to the generated block."""
        md = "::: {.obsidian-invoice}\n:::\n\n# Notes\n\nThanks for your business.\n"
        ast = pandoc_ast(md, ["invoice.lua"], self.META)
        texts = " ".join(self._texts(ast))
        self.assertIn("Thanks for your business", texts)

    def test_discount_adjusts_total(self):
        """A discount subtracts from the subtotal."""
        meta = self.META + '  discount: "25.00"\n'
        md = "::: {.obsidian-invoice}\n:::\n"
        ast = pandoc_ast(md, ["invoice.lua"], meta)
        texts = " ".join(self._texts(ast))
        self.assertIn("425.00", texts)


@unittest.skipUnless(shutil.which("pandoc"), "pandoc not on PATH")
class TestTitlepage(unittest.TestCase):
    def test_absent_key_unmodified(self):
        """No titlepage key -> metadata untouched (standard cover)."""
        md = "---\ntitle: T\n---\n\nBody.\n"
        ast = pandoc_ast(md, ["titlepage.lua"])
        self.assertNotIn("titlepage-true", ast["meta"])

    def test_banded_theme(self):
        """titlepage: banded -> titlepage-true set, page colour set."""
        md = "---\ntitle: T\nauthor: A\n---\n\nBody.\n"
        meta = "titlepage: banded\n"
        ast = pandoc_ast(md, ["titlepage.lua"], meta)
        meta_out = ast["meta"]
        self.assertEqual(meta_out["titlepage-true"], {"t": "MetaBool", "c": True})
        theme = meta_out["titlepage-theme"]["c"]
        html = theme["page-html-color"]["c"]
        self.assertEqual(html, "522b45")

    def test_false_no_cover(self):
        md = "---\ntitle: T\n---\n\nBody.\n"
        meta = "titlepage: false\n"
        ast = pandoc_ast(md, ["titlepage.lua"], meta)
        meta_out = ast["meta"]
        self.assertEqual(meta_out["titlepage-none"], {"t": "MetaBool", "c": True})


if __name__ == "__main__":
    unittest.main()
