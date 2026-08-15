#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Check a commit message subject against the house format.

The rule mirrors the CI commit-format gate: the subject must be
under 50 characters and match '<component>: <imperative summary>'.
Pre-commit runs this as a commit-msg hook with the message file as
the first argument; the CI gate runs the same checks.

Usage:
    check-commit-subject.py COMMIT_MSG_FILE

Exit 0 on a valid subject, 1 with the violation printed otherwise.
"""

import re
import sys

SUBJECT_RE = re.compile(
    r"^(feat|fix|docs|refactor|test|ops|sec|ci|merge|revert)"
    r":[a-z ]+$"
)


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 1
    subject = open(sys.argv[1]).readline().strip()
    if len(subject) > 50:
        print("subject %d chars, max 50: %s" % (len(subject), subject))
        return 1
    if not SUBJECT_RE.match(subject):
        print("subject must be <component>: <imperative summary>: %s" % subject)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
