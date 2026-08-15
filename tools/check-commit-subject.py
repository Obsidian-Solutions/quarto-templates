#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Check a commit message subject against the house format.

The rule mirrors the CI commit-format gate (Obsidian-Solutions/.github
commit-format.yml): the subject must start with a lowercase letter,
then contain ': ' (a colon and a space). The component is NOT
restricted to a fixed list, and uppercase, commas, and hyphens are
allowed after the first letter. The length limit is 50 characters.
Revert commits are exempt in the CI gate (they start with 'Revert').

Pre-commit runs this as a commit-msg hook with the message file as
the first argument; the CI gate runs the same checks.

Usage:
    check-commit-subject.py COMMIT_MSG_FILE

Exit 0 on a valid subject, 1 with the violation printed otherwise.
"""

import re
import sys

# Bash glob in the CI gate: [a-z]*": "*)  ->  lowercase first letter,
# any content, then a colon and a space.
SUBJECT_RE = re.compile(r"^[a-z].*: ")


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 1
    subject = open(sys.argv[1]).readline().strip()
    if len(subject) > 50:
        print("Subject over 50 characters: %s" % subject, file=sys.stderr)
        return 1
    if not SUBJECT_RE.match(subject):
        print(
            "Invalid subject (expected 'component: imperative summary'): %s" % subject,
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
