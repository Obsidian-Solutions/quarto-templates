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

## Releases

Releases are automated. Do not bump versions or write changelog
entries by hand. The release workflow (`.github/workflows/release.yml`)
does the whole job from the version number you give it:

1. Merge the change to `main` with squash.
2. Run the `release` workflow with the new version, for example
   `3.4.0`. Semantic versioning is a judgement call: pick the major,
   minor, or patch step that fits the change.
3. The workflow regenerates `CHANGELOG.md` from the commit history,
   keeps the version homes in step (`_extensions/obsidian/_extension.yml`
   and `scripts/make-sbom.py`), regenerates the SBOM, and creates the
   signed release commit and the signed tag `v3.4.0`.

The workflow needs the signing key as the repository secrets
`GPG_PRIVATE_KEY` and `GPG_PASSPHRASE`. Without them it stops, so a
release baseline is never unsigned (JSP 945).

The generator is `scripts/make-changelog.py`. It is deterministic and
stdlib-only, so the changelog never drifts from the commits. Commit
subjects become changelog entries, so write the subject for the
reader of the release notes: `feat: add the obsidian-beamer format`,
not `feat: updates`.
