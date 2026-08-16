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
entries by hand. The generator does the whole job from the version
number you give it:

1. Merge the change to `main` with squash.
2. Generate the release content: `python3 tools/make-changelog.py --version 3.4.0`.
   This regenerates `CHANGELOG.md` from the commit history, keeps the
   version homes in step (`_extensions/obsidian/_extension.yml` and
   `tools/make-sbom.py`), and regenerates the SBOM. The SBOM records
   the current commit in its document namespace. It is generated
   before the release commit exists, so the committed SBOM lags the
   release by one commit. The lag is deliberate. The CI freshness
   check regenerates the SBOM and compares it with
   `git diff --exit-code`. The committed file must match the tree at
   generation time.
3. Commit and push: `git add -A && git commit -S -m "chore: prepare release v3.4.0" && git push`.
   Sign the commit with your key.
4. Create the release tag locally, annotated and GPG-signed with your
   key: `git tag -s v3.4.0 -m "Release v3.4.0"` and push it with
   `git push origin v3.4.0`. GitHub does not create the tag. The
   owner creates it, so the signature carries the owner's authority.
5. Create the release: `gh release create v3.4.0 --generate-notes`.
   The release points at the tag you pushed, so it carries the
   verified badge.

Semantic versioning is a judgement call: pick the major, minor, or
patch step that fits the change.

The generator is `tools/make-changelog.py`. It is deterministic and
stdlib-only, so the changelog never drifts from the commits. Commit
subjects become changelog entries, so write the subject for the
reader of the release notes: `feat: add the obsidian-beamer format`,
not `feat: updates`.
