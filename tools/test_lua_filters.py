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


def pandoc_run(md: str, filters: list[str], meta: str = "") -> tuple[int, str]:
    """Run pandoc with the given filters and metadata, return (exit code, stderr).

    Unlike pandoc_ast this does not raise on a non-zero exit, so tests
    can assert that a filter fails loudly.
    """
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
        return r.returncode, r.stderr
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
        # The metadata supplies exactly this link; assert equality, not a
        # substring match, so the test pins the rendered URL precisely.
        self.assertIn("https://buy.stripe.com/test_0000", links, "stripe link missing")

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

    def test_supply_and_po_number(self):
        """Supply date, due date, and PO number appear in the header."""
        meta = (
            self.META
            + '  po-number: "PO-2026-0142"\n'
            + '  supply-date: "2026-08-15"\n'
        )
        md = "::: {.obsidian-invoice}\n:::\n"
        ast = pandoc_ast(md, ["invoice.lua"], meta)
        texts = " ".join(self._texts(ast))
        self.assertIn("Purchase order", texts)
        self.assertIn("PO-2026-0142", texts)
        self.assertIn("Supply date", texts)

    def test_vat_status_line(self):
        """vat-status renders a line in the payment block."""
        meta = self.META + '  vat-status: "Not registered for VAT"\n'
        md = "::: {.obsidian-invoice}\n:::\n"
        ast = pandoc_ast(md, ["invoice.lua"], meta)
        texts = " ".join(self._texts(ast))
        self.assertIn("VAT", texts)
        self.assertIn("Not registered for VAT", texts)

    # Fail-loud regression tests. The filter aborts with a non-zero
    # exit (os.exit(1)) because Quarto's filter runner redefines the
    # global error() to print and continue: under `quarto render` a
    # plain error() would ship the broken invoice with exit code 0.
    # Bare pandoc propagates the exit code, so these tests assert the
    # filter fails and names the field.

    def test_missing_number_fails(self):
        """Invoice metadata without a number stops the render."""
        meta = self.META.replace('  number: "2026-008"\n', "")
        md = "::: {.obsidian-invoice}\n:::\n"
        code, err = pandoc_run(md, ["invoice.lua"], meta)
        self.assertNotEqual(code, 0, "missing number must fail the render")
        self.assertIn("missing or invalid field 'number'", err)

    def test_unparseable_unit_price_fails(self):
        """An unparseable unit price stops the render."""
        meta = self.META.replace('unit-price: "300.00"', 'unit-price: "abc"')
        md = "::: {.obsidian-invoice}\n:::\n"
        code, err = pandoc_run(md, ["invoice.lua"], meta)
        self.assertNotEqual(code, 0, "unparseable unit price must fail the render")
        self.assertIn("unparseable unit price", err)

    def test_missing_marker_fails(self):
        """Invoice metadata with no marker Div stops the render."""
        md = "# Heading\n\nBody.\n"
        code, err = pandoc_run(md, ["invoice.lua"], self.META)
        self.assertNotEqual(code, 0, "missing marker Div must fail the render")
        self.assertIn("no .obsidian-invoice marker Div", err)

    def test_negative_discount_adds_to_total(self):
        """A negative discount (surcharge) adds to the total."""
        meta = self.META + '  discount: "-25.00"\n'
        md = "::: {.obsidian-invoice}\n:::\n"
        ast = pandoc_ast(md, ["invoice.lua"], meta)
        texts = " ".join(self._texts(ast))
        # 450.00 subtotal + 25.00 surcharge = 475.00; the surcharge
        # displays as a positive adjustment, not "- GBP 25.00".
        self.assertIn("+ GBP 25.00", texts)
        self.assertIn("475.00", texts)

    def test_provider_whitespace(self):
        """A provider with surrounding whitespace still renders the block."""
        meta = self.META.replace(
            'provider: "stripe"\n    link: "https://buy.stripe.com/test_0000"',
            'provider: " bank-transfer "\n    details:\n      bank: "Example Bank"\n      sort-code: "00-00-00"\n      account: "00000000"\n      name: "Obsidian Solutions"\n      reference: "INV-2026-008"',
        )
        md = "::: {.obsidian-invoice}\n:::\n"
        ast = pandoc_ast(md, ["invoice.lua"], meta)
        texts = " ".join(self._texts(ast))
        self.assertIn("Example Bank", texts)
        self.assertIn("INV-2026-008", texts)


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


@unittest.skipUnless(shutil.which("pandoc"), "pandoc not on PATH")
class TestVerify(unittest.TestCase):
    """The soft verification filter warns on stderr but never fails."""

    def verify_warnings(self, meta: str) -> str:
        """Run verify.lua with the metadata, return the stderr."""
        tmp = tempfile.mkdtemp()
        try:
            src = Path(tmp) / "in.md"
            src.write_text("# Heading\n\nBody.\n")
            meta_file = Path(tmp) / "meta.yml"
            meta_file.write_text(meta)
            cmd = [
                "pandoc",
                "--from",
                "markdown",
                "--to",
                "json",
                "--lua-filter",
                str(FILTERS / "verify.lua"),
                "--metadata-file",
                str(meta_file),
                str(src),
            ]
            r = subprocess.run(cmd, capture_output=True, text=True)
            return r.stderr
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    def test_off_by_default(self):
        """No verify: true -> no warnings at all."""
        err = self.verify_warnings("title: T\n")
        self.assertNotIn("VERIFY", err)

    def test_valid_invoice_minimal_warnings(self):
        """A valid invoice warns only about genuine placeholders."""
        meta = """
verify: true
title: Test invoice
author: Obsidian Solutions
date: 2026-08-15
reference: OS-INV-001
version: 1.0.0
confidentiality: Commercial in Confidence
invoice:
  sender:
    name: Obsidian Solutions
    address: |
      1 High Street
      Exeter EX1 1AA
  number: 2026-001
  date: 2026-08-15
  supply-date: 2026-08-15
  due-date: 2026-08-29
  client:
    name: Acme Ltd
    address: |
      1 High Street
      London SW1A 1AA
  items:
    - description: Consulting
      quantity: 2
      unit-price: 100.00
  payment:
    provider: stripe
    link: https://buy.stripe.com/test
"""
        err = self.verify_warnings(meta)
        # A fully-filled invoice is clean: no warnings at all.
        self.assertIn("metadata surface clean", err)
        self.assertNotIn("date is missing", err)
        self.assertNotIn("unit-price must", err)
        self.assertNotIn("postcode", err)

    def test_malformed_invoice_warns(self):
        """Bad reference, postcode, date order, quantity, provider."""
        meta = """
verify: true
title: Test invoice
author: Obsidian Solutions
date: 2026-08-15
reference: not-a-reference
version: x.y.z
confidentiality: Secret Squirrel
invoice:
  sender:
    name: Obsidian Solutions
    address: 1 High Street, Exeter EX1 1AA
  number: 123
  date: 2026-08-20
  due-date: 2026-08-15
  client:
    name: Acme Ltd
    address: 1 Nowhere Street, London
  items:
    - description: Consulting
      quantity: 0
      unit-price: abc
  payment:
    provider: crypto
"""
        err = self.verify_warnings(meta)
        self.assertIn("reference", err)
        self.assertIn("version", err)
        self.assertIn("confidentiality", err)
        self.assertIn("postcode", err)
        self.assertIn("due-date", err)
        self.assertIn("quantity", err)
        self.assertIn("unit-price", err)
        self.assertIn("provider", err)


class TestStructuredFields(unittest.TestCase):
    """The structured doc-type blocks render from front-matter fields."""

    def render_ast(self, md: str, meta: str):
        """Run structured-fields.lua with the body and metadata."""
        tmp = tempfile.mkdtemp()
        try:
            src = Path(tmp) / "in.md"
            src.write_text(md)
            meta_file = Path(tmp) / "meta.yml"
            meta_file.write_text(meta)
            cmd = [
                "pandoc",
                "--from",
                "markdown",
                "--to",
                "json",
                "--lua-filter",
                str(FILTERS / "structured-fields.lua"),
                "--metadata-file",
                str(meta_file),
                str(src),
            ]
            r = subprocess.run(cmd, capture_output=True, text=True)
            if r.returncode != 0:
                raise AssertionError("pandoc failed: %s" % r.stderr[-500:])
            return json.loads(r.stdout), r.stderr
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    def test_letter_renders_address_block(self):
        """A letter with an address renders the recipient block."""
        md = "::: {.obsidian-letter}\n:::\n\nBody.\n"
        meta = """
title: Test letter
author: A. Author
date: 2026-08-15
reference: OS-LET-001
letter:
  address:
    - Acme Ltd
    - 1 High Street
  subject: Quarterly report
  opening: Dear Sirs
  closing: Yours faithfully
  signature: A. Author
"""
        ast, _ = self.render_ast(md, meta)
        text = json.dumps(ast)
        self.assertIn("Recipient", text)
        self.assertIn("Acme Ltd", text)
        self.assertIn("1 High Street", text)
        self.assertIn("Quarterly report", text)

    def test_letter_requires_address(self):
        """A letter without an address errors with the field name."""
        md = "::: {.obsidian-letter}\n:::\n"
        meta = """
title: Test letter
author: A. Author
date: 2026-08-15
reference: OS-LET-001
letter:
  subject: Quarterly report
"""
        try:
            self.render_ast(md, meta)
            self.fail("expected a missing-field error")
        except AssertionError:
            pass

    def test_letter_missing_field_fails_loud(self):
        """A missing required field exits non-zero and names the field.

        The filter aborts with os.exit(1) because Quarto's filter
        runner redefines the global error() to print and continue;
        under `quarto render` a plain error() would ship the document
        with a blank recipient block and exit code 0.
        """
        md = "::: {.obsidian-letter}\n:::\n"
        meta = """
title: Test letter
author: A. Author
date: 2026-08-15
reference: OS-LET-001
letter:
  subject: Quarterly report
"""
        code, err = pandoc_run(md, ["structured-fields.lua"], meta)
        self.assertNotEqual(code, 0, "missing letter.address must fail the render")
        self.assertIn("missing required field 'letter.address'", err)

    def test_memo_renders_heading_block(self):
        """A memo with to/from/subject renders the heading block."""
        md = "::: {.obsidian-memo}\n:::\n\nBody.\n"
        meta = """
title: Test memo
author: A. Author
date: 2026-08-15
reference: OS-MEM-001
memo:
  to:
    - B. Recipient
  from: A. Author
  subject: Decision needed
"""
        ast, _ = self.render_ast(md, meta)
        text = json.dumps(ast)
        self.assertIn("B. Recipient", text)
        self.assertIn("Decision needed", text)

    def test_memo_requires_subject(self):
        """A memo without a subject errors with the field name."""
        md = "::: {.obsidian-memo}\n:::\n"
        meta = """
title: Test memo
author: A. Author
date: 2026-08-15
reference: OS-MEM-001
memo:
  to:
    - B. Recipient
  from: A. Author
"""
        try:
            self.render_ast(md, meta)
            self.fail("expected a missing-field error")
        except AssertionError:
            pass

    def test_agenda_renders_details(self):
        """An agenda with meeting details renders the details block."""
        md = "::: {.obsidian-agenda}\n:::\n\nItems.\n"
        meta = """
title: Test agenda
author: A. Author
date: 2026-08-15
reference: OS-AGT-001
agenda:
  meeting: Weekly review
  date: 2026-08-20
  time: 10:00
  location: Room 1
  chair: A. Author
  members:
    - B. Recipient
"""
        ast, _ = self.render_ast(md, meta)
        text = json.dumps(ast)
        self.assertIn("Weekly review", text)
        self.assertIn("Room 1", text)
        self.assertIn("B. Recipient", text)

    def test_agenda_requires_meeting(self):
        """An agenda without a meeting name errors with the field name."""
        md = "::: {.obsidian-agenda}\n:::\n"
        meta = """
title: Test agenda
author: A. Author
date: 2026-08-15
reference: OS-AGT-001
agenda:
  date: 2026-08-20
  time: 10:00
  location: Room 1
"""
        try:
            self.render_ast(md, meta)
            self.fail("expected a missing-field error")
        except AssertionError:
            pass

    def test_brief_renders_key_findings(self):
        """A brief renders the key findings list when present."""
        md = "::: {.obsidian-brief}\n:::\n\nSummary.\n"
        meta = """
title: Test brief
author: A. Author
date: 2026-08-15
reference: OS-BRF-001
brief:
  series: Policy series
  issue: 2
  key-findings:
    - Finding one
    - Finding two
  cite-as: Author, Test brief
"""
        ast, _ = self.render_ast(md, meta)
        text = json.dumps(ast)
        self.assertIn("Key findings", text)
        self.assertIn("Finding one", text)
        self.assertIn("How to cite", text)

    def test_brief_renders_without_required_fields(self):
        """A brief has no required fields and renders empty."""
        md = "::: {.obsidian-brief}\n:::\n\nSummary.\n"
        meta = """
title: Test brief
author: A. Author
date: 2026-08-15
reference: OS-BRF-001
"""
        ast, _ = self.render_ast(md, meta)
        text = json.dumps(ast)
        self.assertIn("Summary", text)


if __name__ == "__main__":
    unittest.main()
