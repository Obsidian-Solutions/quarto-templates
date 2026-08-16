#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Tests for verify.lua, driven through pandoc directly.

Mirrors the harness in tools/test_lua_filters.py: each test runs
pandoc with the verify filter on a tiny markdown input and inspects
the stderr warnings. verify.lua is opt-in via `verify: true` and
never fails the render.

Run with:  python3 -m unittest tools.test_verify -v
"""

import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
FILTERS = TOOLS.parent / "_extensions" / "obsidian" / "filters"


def verify_warnings(meta: str) -> str:
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


@unittest.skipUnless(shutil.which("pandoc"), "pandoc not on PATH")
class TestVerifyLevels(unittest.TestCase):
    """The confidentiality level set matches the canonical list."""

    def _meta(self, level: str) -> str:
        return (
            "verify: true\n"
            "title: Test\n"
            "author: A. Author\n"
            "date: 2026-08-15\n"
            "reference: OS-TST-001\n"
            "version: 1.0.0\n"
            "confidentiality: %s\n" % level
        )

    def test_open_accepted(self):
        err = verify_warnings(self._meta("Open"))
        self.assertNotIn("unrecognised level", err)

    def test_official_accepted(self):
        err = verify_warnings(self._meta("Official"))
        self.assertNotIn("unrecognised level", err)

    def test_official_sensitive_with_reason_accepted(self):
        """The GSCP colon form must not warn (the gate accepts it)."""
        err = verify_warnings(self._meta("OFFICIAL-SENSITIVE: for example only"))
        self.assertNotIn("unrecognised level", err)

    def test_restricted_warns(self):
        """Restricted is obsolete under GSCP v2.0; the documented choice warns."""
        err = verify_warnings(self._meta("Restricted"))
        self.assertIn("unrecognised level", err)

    def test_unclassified_warns(self):
        """Unclassified is not a GSCP level; the documented choice warns."""
        err = verify_warnings(self._meta("Unclassified"))
        self.assertIn("unrecognised level", err)

    def test_confidential_warns(self):
        """Confidential is obsolete under GSCP v2.0; the documented choice warns."""
        err = verify_warnings(self._meta("Confidential"))
        self.assertIn("unrecognised level", err)


@unittest.skipUnless(shutil.which("pandoc"), "pandoc not on PATH")
class TestVerifyInvoice(unittest.TestCase):
    """verify.lua must not warn on renderable invoices."""

    BASE = """
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
  client:
    name: Acme Ltd
    address: |
      1 High Street
      London SW1A 1AA
  items:
    - description: Consulting
      quantity: 1
      unit-price: "300.00"
  payment:
    provider: stripe
    link: https://buy.stripe.com/test
"""

    def test_optional_dates_absent_no_warning(self):
        """supply-date and due-date are optional; absence must not warn."""
        err = verify_warnings(self.BASE)
        self.assertNotIn("date is missing", err)

    def test_provider_generic_no_warning(self):
        """generic is a first-class provider in invoice.lua."""
        meta = self.BASE.replace("provider: stripe", "provider: generic")
        err = verify_warnings(meta)
        self.assertNotIn("unrecognised provider", err)

    def test_sender_absent_with_author_no_warning(self):
        """invoice.lua falls back to the document author for the letterhead."""
        meta = self.BASE.replace(
            "  sender:\n"
            "    name: Obsidian Solutions\n"
            "    address: |\n"
            "      1 High Street\n"
            "      Exeter EX1 1AA\n",
            "",
        )
        err = verify_warnings(meta)
        self.assertNotIn("sender block is missing", err)

    def test_sender_absent_without_author_warns(self):
        """No sender and no author means nothing to render; warn."""
        meta = self.BASE.replace(
            "  sender:\n"
            "    name: Obsidian Solutions\n"
            "    address: |\n"
            "      1 High Street\n"
            "      Exeter EX1 1AA\n",
            "",
        ).replace("author: Obsidian Solutions\n", "")
        err = verify_warnings(meta)
        self.assertIn("sender block is missing", err)

    def test_sender_contact_uk_phone_no_warning(self):
        """A real UK phone in sender.contact must not warn."""
        meta = self.BASE.replace(
            "  sender:\n    name: Obsidian Solutions\n",
            "  sender:\n    name: Obsidian Solutions\n    contact: +44 7700 900123\n",
            1,
        )
        err = verify_warnings(meta)
        self.assertNotIn("does not look like a phone number", err)

    def test_sender_contact_loose_line_no_warning(self):
        """A real 'email | phone' combined contact line must not warn."""
        meta = self.BASE.replace(
            "  sender:\n    name: Obsidian Solutions\n",
            "  sender:\n    name: Obsidian Solutions\n"
            "    contact: accounts@example.com | 07700 900123\n",
            1,
        )
        err = verify_warnings(meta)
        self.assertNotIn("does not look like a phone number", err)

    def test_sender_contact_garbage_warns(self):
        """A contact line of pure text (no phone fragment) warns."""
        meta = self.BASE.replace(
            "  sender:\n    name: Obsidian Solutions\n",
            "  sender:\n    name: Obsidian Solutions\n    contact: call the office\n",
            1,
        )
        err = verify_warnings(meta)
        self.assertIn("does not look like a phone number", err)

    def test_pound_symbol_price_no_warning(self):
        """'£300.00' parses as money; no spurious price warning."""
        meta = self.BASE.replace('unit-price: "300.00"', 'unit-price: "£300.00"')
        meta = meta.replace(
            "  date: 2026-08-15\n", '  date: 2026-08-15\n  subtotal: "300.00"\n', 1
        )
        err = verify_warnings(meta)
        self.assertNotIn("unit-price must", err)
        self.assertNotIn("invoice.subtotal", err)

    def test_gbp_prefix_price_no_warning(self):
        """'GBP 300.00' parses as money; subtotal recompute is correct."""
        meta = self.BASE.replace('unit-price: "300.00"', 'unit-price: "GBP 300.00"')
        meta = meta.replace(
            "  date: 2026-08-15\n", '  date: 2026-08-15\n  subtotal: "300.00"\n', 1
        )
        err = verify_warnings(meta)
        self.assertNotIn("unit-price must", err)
        self.assertNotIn("invoice.subtotal", err)

    def test_unparseable_price_warns(self):
        """A genuinely unparseable price still fails."""
        meta = self.BASE.replace('unit-price: "300.00"', 'unit-price: "abc"')
        err = verify_warnings(meta)
        self.assertIn("unit price must", err)

    def test_negative_unit_price_warns(self):
        """A negative unit price is still invalid."""
        meta = self.BASE.replace('unit-price: "300.00"', 'unit-price: "-300.00"')
        err = verify_warnings(meta)
        self.assertIn("unit price must", err)

    def test_vat_bare_nine_digits(self):
        meta = self.BASE + '  vat-status: "123456789"\n'
        err = verify_warnings(meta)
        self.assertNotIn("vat-status", err)

    def test_vat_gb_nine_digits(self):
        meta = self.BASE + '  vat-status: "GB123456789"\n'
        err = verify_warnings(meta)
        self.assertNotIn("vat-status", err)

    def test_vat_gb_twelve_digits(self):
        """GB+12 covers branch and group registrations."""
        meta = self.BASE + '  vat-status: "GB123456789012"\n'
        err = verify_warnings(meta)
        self.assertNotIn("vat-status", err)

    def test_vat_xi_nine_digits(self):
        """XI covers Northern Ireland registrations."""
        meta = self.BASE + '  vat-status: "XI123456789"\n'
        err = verify_warnings(meta)
        self.assertNotIn("vat-status", err)

    def test_vat_old_13_char_form_rejected(self):
        """The GB+9+2letters form has no official basis; it warns."""
        meta = self.BASE + '  vat-status: "GB123456789AB"\n'
        err = verify_warnings(meta)
        self.assertIn("vat-status", err)

    def test_vat_not_registered_accepted(self):
        meta = self.BASE + '  vat-status: "Not registered for VAT"\n'
        err = verify_warnings(meta)
        self.assertNotIn("vat-status", err)

    def test_vat_free_text_with_number(self):
        """A number inside free text must not false-positive."""
        meta = self.BASE + '  vat-status: "VAT number: GB123456789"\n'
        err = verify_warnings(meta)
        self.assertNotIn("vat-status", err)


if __name__ == "__main__":
    unittest.main()
