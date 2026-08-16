#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Tests for has-floats.lua: the List of Tables / List of Figures gate.

has-floats.lua sets the has-tables / has-figures metadata flags that
toc.tex uses to render the List of Tables / List of Figures pages.
A table is listable only when it has a caption: \listoftables lists
captions. Layout tables (invoice line items, totals) carry empty
captions and must not set has-tables.

Regression under test: the invoice filter generates captionless
tables inside a Div that also contains text. The old Div-text
heuristic counted them, so any invoice rendered an empty List of
Tables page on the default lot:true path.

Run with:  python3 -m unittest tools/test_floats.py
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


def has_tables(ast: dict) -> bool:
    return ast["meta"].get("has-tables", {}).get("c", False)


def has_figures(ast: dict) -> bool:
    return ast["meta"].get("has-figures", {}).get("c", False)


INVOICE_META = """
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
  payment:
    terms: "Due within 14 days"
    provider: "stripe"
    link: "https://buy.stripe.com/test_0000"
"""


@unittest.skipUnless(shutil.which("pandoc"), "pandoc not on PATH")
class TestHasFloats(unittest.TestCase):
    def test_invoice_tables_not_listed(self):
        """Invoice tables (empty captions) must not set has-tables."""
        md = "::: {.obsidian-invoice}\n:::\n"
        ast = pandoc_ast(md, ["invoice.lua", "has-floats.lua"], INVOICE_META)
        self.assertFalse(has_tables(ast), "invoice tables set has-tables")

    def test_captioned_table_listed(self):
        """A genuinely captioned table sets has-tables."""
        md = "| A | B |\n|---|---|\n| 1 | 2 |\n\n: A captioned table.\n"
        ast = pandoc_ast(md, ["has-floats.lua"])
        self.assertTrue(has_tables(ast), "captioned table did not set has-tables")

    def test_labelled_table_listed(self):
        """A #tbl- labelled table sets has-tables."""
        md = "| A | B |\n|---|---|\n| 1 | 2 |\n\n: Data summary {#tbl-data}\n"
        ast = pandoc_ast(md, ["has-floats.lua"])
        self.assertTrue(has_tables(ast), "labelled table did not set has-tables")

    def test_captionless_table_not_listed(self):
        """A bare captionless layout table must not set has-tables."""
        md = "| A | B |\n|---|---|\n| 1 | 2 |\n"
        ast = pandoc_ast(md, ["has-floats.lua"])
        self.assertFalse(has_tables(ast), "captionless table set has-tables")

    def test_no_tables_no_flag(self):
        """A document with no tables leaves has-tables false."""
        md = "# H\n\nBody.\n"
        ast = pandoc_ast(md, ["has-floats.lua"])
        self.assertFalse(has_tables(ast))

    def test_figure_sets_has_figures(self):
        """A figure sets has-figures."""
        md = "![A figure](img.png)\n"
        ast = pandoc_ast(md, ["has-floats.lua"])
        self.assertTrue(has_figures(ast), "figure did not set has-figures")

    def test_captioned_table_in_div_listed(self):
        """A captioned table inside a Div still sets has-tables."""
        md = "::: {.wrapper}\n\n| A | B |\n|---|---|\n| 1 | 2 |\n\n: Wrapped caption.\n\n:::\n"
        ast = pandoc_ast(md, ["has-floats.lua"])
        self.assertTrue(has_tables(ast), "wrapped captioned table not listed")


if __name__ == "__main__":
    unittest.main()
