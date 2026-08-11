# Contributing

Thank you for contributing to this project.

## Before you start

- Find or create a ticket for the change in your issue tracker.
- Branch from `main`. Do not work directly on `main`.
- Name your branch in the format `type/issue-id-short-description`.

| Type | Use for |
|---|---|
| feat | new capability |
| fix | defect correction |
| docs | documentation only |
| refactor | internal change with no behaviour change |
| test | test changes only |
| ops | operations, CI, infrastructure |
| sec | security fix |

## Commit messages

Write commit messages in the format:

```
component: imperative summary

- change rationale
- ticket or issue reference
- configuration baseline if applicable
```

Rules:

- Subject line under 50 characters, imperative, no full stop
- Body explains what changed, why, and what it links to
- Sign every commit with GPG

## Pull requests

- Open a pull request against `main`.
- Reference the ticket or issue in the description.
- Complete the pull request checklist.
- Request review from the team named in CODEOWNERS.
- Address all review comments before merge.
- Merge with squash to keep a linear history.

## Licence headers

Add an SPDX licence identifier to the top of every source file:

```
SPDX-License-Identifier: MIT
```

Use the SPDX identifier that matches the project licence. See
https://spdx.org/licenses/ for the full list.

## Definition of done

A change is done when:

- Tests pass
- Lint checks pass
- SAST and SCA checks pass
- Code review is complete
- Documentation is updated
- No secrets are committed
