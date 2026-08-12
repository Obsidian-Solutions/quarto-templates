#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""check-ste.py - controlled-language gate (JSP 101 / ASD-STE100).

Portable, stdlib-only checker for a Quarto document source. The word
lists are embedded so the gate works without the machine-specific
linter at ~/.config/opencode/rules/ste-lint.py. Keep the lists in
step with that file when it changes (summary: rules/ste-wordlists.md).

Extracts plain text from a .qmd (front matter, fenced and inline
code, and blockquotes removed - blockquotes hold verbatim quoted
material, and the writers-handbook forbids changing quotes). Reports
hard violations (banned words, marketing adjectives, phrasal verbs,
modal hedges, contractions, American spellings, em dashes) and style
warnings (long sentences, semicolons, passive voice, -ing main
verbs, nominalisation, long paragraphs).

A document can opt out with `ste: false` in its front matter (for
example to quote external material verbatim).

Usage: python3 scripts/check-ste.py document.qmd
Exit codes: 0 = clean, 1 = hard violations, 2 = usage error.
"""

import re
import sys

# Word lists copied from rules/ste-lint.py (source of truth).
MARKETING = [
    "seamless",
    "seamlessly",
    "robust",
    "powerful",
    "cutting-edge",
    "effortless",
    "effortlessly",
    "world-class",
    "next-generation",
    "revolutionary",
    "blazing",
    "lightning-fast",
    "elegant",
    "delightful",
    "turnkey",
    "best-in-class",
    "state-of-the-art",
    "game-changing",
    "first-class",
    "battle-tested",
    "enterprise-grade",
    "supercharge",
    "unlock",
    "unleash",
    "empower",
    "empowers",
]
BANNED = [
    "begin",
    "begins",
    "commence",
    "commences",
    "initiate",
    "initiates",
    "originate",
    "utilize",
    "utilizes",
    "utilizing",
    "utilise",
    "license",
    "licenses",
    "colorful",
    "defenseless",
    "honorable",
    "theater",
    "fiber",
    "labeling",
    "traveling",
    "centering",
    "offense",
    "practiced",
    "utilises",
    "utilised",
    "utilising",
    "utilisation",
    "leverage",
    "leverages",
    "leveraging",
    "facilitate",
    "facilitates",
    "ensure",
    "ensures",
    "ensuring",
    "prior to",
    "subsequent to",
    "obtain",
    "obtains",
    "acquire",
    "acquires",
    "regarding",
    "concerning",
    "demonstrate",
    "demonstrates",
    "additionally",
    "furthermore",
    "moreover",
    "comprehensive",
    "comprehensively",
    "utilization",
    "aforementioned",
    # American spellings (British -ise/-yse/-our/-re mandated).
    "organize",
    "organizes",
    "organized",
    "organizing",
    "organization",
    "organizations",
    "analyze",
    "analyzes",
    "analyzed",
    "analyzing",
    "realize",
    "realizes",
    "realized",
    "realizing",
    "recognize",
    "recognizes",
    "recognized",
    "recognizing",
    "emphasize",
    "emphasizes",
    "emphasized",
    "emphasizing",
    "maximize",
    "maximizes",
    "maximized",
    "maximizing",
    "minimize",
    "minimizes",
    "minimized",
    "minimizing",
    "optimize",
    "optimizes",
    "optimized",
    "optimizing",
    "prioritize",
    "prioritizes",
    "prioritized",
    "prioritizing",
    "customize",
    "customizes",
    "customized",
    "customizing",
    "summarize",
    "summarizes",
    "summarized",
    "summarizing",
    "specialize",
    "specializes",
    "specialized",
    "specializing",
    "categorize",
    "categorizes",
    "categorized",
    "categorizing",
    "authorize",
    "authorizes",
    "authorized",
    "authorizing",
    "characterize",
    "characterizes",
    "characterized",
    "characterizing",
    "generalize",
    "generalizes",
    "generalized",
    "generalizing",
    "formalize",
    "formalizes",
    "formalized",
    "formalizing",
    "normalize",
    "normalizes",
    "normalized",
    "normalizing",
    "initialize",
    "initializes",
    "initialized",
    "initializing",
    "standardize",
    "standardizes",
    "standardized",
    "standardizing",
    "visualize",
    "visualizes",
    "visualized",
    "visualizing",
    "finalize",
    "finalizes",
    "finalized",
    "finalizing",
    "familiarize",
    "familiarizes",
    "familiarized",
    "familiarizing",
    "fulfill",
    "fulfills",
    "fulfilling",
    "fulfillment",
    "program",
    "programs",
    "authorization",
    "authorizations",
    "reauthorization",
    "specialization",
    "specializations",
    "categorization",
    "categorizations",
    "realization",
    "realizations",
    "normalization",
    "normalizations",
    "standardization",
    "standardizations",
    "optimization",
    "optimizations",
    "customization",
    "customizations",
    "initialization",
    "initializations",
    "generalization",
    "generalizations",
    "formalization",
    "formalizations",
    "visualization",
    "visualizations",
    "finalization",
    "finalizations",
    "familiarization",
    "familiarizations",
    "minimization",
    "minimizations",
    "maximization",
    "maximizations",
    "prioritization",
    "prioritizations",
    "color",
    "colors",
    "colored",
    "coloring",
    "defense",
    "behavior",
    "behaviors",
    "center",
    "centers",
    "centered",
    "labor",
    "favorite",
    "honor",
    "honored",
    "modeling",
    "canceled",
    "canceling",
    "gray",
    "henceforth",
    "therein",
    "whilst",
    "amongst",
    "numerous",
    "myriad",
    "plethora",
    "in order to",
    "a variety of",
    "in the event that",
    "due to the fact that",
]
PHRASAL = [
    "spin up",
    "spin down",
    "reach out",
    "dive into",
    "dives into",
    "diving into",
    "kick off",
    "kicks off",
    "roll out",
    "rolls out",
    "tear down",
    "ramp up",
    "circle back",
    "drill down",
    "spun up",
    "reaching out",
]
MODAL_HEDGE = [
    "it is important to note",
    "it should be noted",
    "it is worth noting",
    "please note that",
    "as mentioned",
    "as noted above",
]
BE = r"(?:am|is|are|was|were|be|been|being)"
PP_IRREG = r"(?:done|made|sent|read|built|kept|held|set|put|run|written|shown|given|taken|found|got|gotten|seen|known|thrown|drawn)"

CONTRACTION_RE = re.compile(
    r"\b(?:it|that|there|he|she|who|what|how|let)['\u2019]s\b"
    r"|\b\w+['\u2019](?:t|re|ve|ll|d|m)\b"
)
EM_DASH = "\u2014"
LONG_SENTENCE = 20


def strip_frontmatter(text):
    """Remove YAML front matter; report the ste: opt-out flag."""
    if text.startswith("---"):
        parts = text.split("---", 2)
        if len(parts) == 3:
            if re.search(r"(?m)^\s*ste:\s*(?:false|no)\s*$", parts[1]):
                return parts[2], True
            return parts[2], False
    return text, False


def strip_code(text):
    t = re.sub(r"```.*?```", " ", text, flags=re.S)
    t = re.sub(r"`[^`]*`", " ", t)
    # Handbook-first: blockquotes hold verbatim quoted material; exempt.
    t = re.sub(r"(?m)^\s*>\s?.*$", " ", t)
    return t


def sentences(text):
    out = []
    for line in text.split("\n"):
        s = line.strip()
        if not s:
            continue
        s = re.sub(r"^\s*#{1,6}\s*", "", s)
        s = re.sub(r"^\s*(?:[-*+]|\d+[.)])\s+", "", s)
        if not s:
            continue
        for p in re.split(r"(?<=[.!?:])\s+(?=[A-Z0-9\"'\u2013])", s):
            p = p.strip()
            if p:
                out.append(p)
    return out


def wc(s):
    return len([w for w in re.findall(r"[A-Za-z0-9][A-Za-z0-9'\-/]*", s)])


def count_ci(text, phrases):
    low = text.lower()
    hits = []
    for ph in phrases:
        for m in re.finditer(r"(?<![a-z])" + re.escape(ph) + r"(?![a-z])", low):
            hits.append(ph)
    return hits


def bullet_semicolons(text):
    """MOD Writers' Handbook: continuous bullet lists end each item with a
    semicolon. Do not count semicolons on bullet, numbered, or table lines."""
    n = 0
    for line in text.split("\n"):
        s = line.strip()
        if re.match(r"^(?:[-*+]|\d+[.)])\s+", s) and s.rstrip().endswith(";"):
            n += 1
            continue
        if re.match(r"^\|", s) and ";" in s:
            n += s.count(";")
            continue
        if (
            re.match(r"^\s", line)
            and ";" in line
            and re.match(r"^\s*(?:[-*+]|\d+[.)])", line)
        ):
            n += line.count(";")
    return n


def check(text):
    raw, opted_out = strip_frontmatter(text)
    if opted_out:
        return None
    body = strip_code(raw)
    sents = sentences(body)
    hard, warns = [], []

    for label, lst in (
        ("banned word", BANNED),
        ("marketing adjective", MARKETING),
        ("phrasal verb", PHRASAL),
        ("modal hedge", MODAL_HEDGE),
    ):
        for hit in count_ci(body, lst):
            hard.append(f"{label}: {hit!r}")

    for m in CONTRACTION_RE.finditer(body):
        hard.append(f"contraction: {m.group(0)!r} (write the full words)")

    if EM_DASH in raw:
        hard.append("em dash (U+2014): use the en dash with spaces, or a full stop")

    for n, s in ((wc(s), s) for s in sents if wc(s) > LONG_SENTENCE):
        warns.append(f"long sentence ({n} words, max {LONG_SENTENCE}): {s}")

    semi = body.count(";") - bullet_semicolons(raw)
    # Citation separators ([@key1; @key2]) are not sentence punctuation.
    semi -= len(re.findall(r"\[[^\]]*;", body))
    if semi:
        warns.append(f"{semi} semicolon(s): write two sentences instead")

    passive = len(re.findall(rf"\b{BE}\s+(?:\w+ed|{PP_IRREG})\b", body, re.I))
    if passive:
        warns.append(f"{passive} passive-voice verb(s): use the active voice")

    ing = len(re.findall(rf"\b{BE}\s+\w+ing\b", body, re.I))
    if ing:
        warns.append(f"{ing} '-ing' main verb(s): use a simple tense")

    paras = [p for p in re.split(r"\n\s*\n", raw) if p.strip()]
    # A table block is not a paragraph: drop its rows before counting.
    paras = [re.sub(r"(?m)^\s*\|.*$", "", p) for p in paras]
    long_paras = sum(1 for p in paras if len(sentences(strip_code(p))) > 6)
    if long_paras:
        warns.append(f"{long_paras} paragraph(s) with more than 6 sentences")

    return hard, warns


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: check-ste.py document.qmd")
        return 2
    with open(sys.argv[1], encoding="utf-8") as fh:
        result = check(fh.read())
    if result is None:
        print("STE: skipped (ste: false in front matter)")
        return 0
    hard, warns = result
    for w in warns:
        print(f"WARN: {w}")
    for h in hard:
        print(f"FAIL: {h}")
    if hard:
        print(
            f"STE GATE FAILED: {len(hard)} hard violation(s). "
            "Fix them, or set `ste: false` in the front matter to "
            "quote external material verbatim."
        )
        return 1
    print(f"STE: pass ({len(warns)} warning(s), 0 violations)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
