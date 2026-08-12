# GitHub Settings

This file records the GitHub repository settings that protect `main`
and enable the release pipeline. The settings live in the GitHub web
interface, not in the repository, so this file is the written record
(Defence Digital requires branch protection on `main`). Apply each
setting when the repository is created or when a setting is missing.

## Branch protection on `main`

Use a branch protection rule or a ruleset on the `main` branch:

- Require a pull request before merging
- Require at least 1 approval
- Require status checks to pass:
  - `render-and-validate` (the render and validation gates)
  - `CodeQL` (static analysis)
- Require signed commits
- Require linear history (squash merging)
- Require the branch to be up to date before merging
- Do not allow force pushes
- Do not allow deletions

CODEOWNERS protects the sensitive paths: review requests go to the
owner until a team exists.

## Static analysis

SAST is the GitHub default code scanning setup, configured in the
repository settings under Code security and analysis. It analyses
the Python tooling and the GitHub Actions, and it reports findings
to the Security tab. There is no CodeQL workflow file in this
repository: default setup runs the analysis, so there is nothing to
maintain. The scanner also enforces the workflow hygiene rules:
every action reference is pinned to a commit SHA, and every
workflow declares an explicit least-privilege `permissions` block.
A workflow that violates either rule fails the scan, not the build.

## Secret scanning

In the repository settings under Code security and analysis:

- Enable secret scanning
- Enable push protection, so secrets cannot be committed in the
  first place (NCSC Secure Development: separate secret credentials
  from the code base)

## Releases

Releases are created with `gh release create vX.Y.Z` (see the release
procedure in CONTRIBUTING.md). GitHub creates the tag and signs it
with GitHub's key, so the release carries the verified badge. No
GPG secrets are stored: the repository is the sole trader's own, so
the account signature carries the owner's authority. The
`GPG_PRIVATE_KEY` and `GPG_PASSPHRASE` secrets are not required.

## Dependabot

The `dependabot.yml` manifest enables version updates for the GitHub
Actions. Keep them enabled. Every action reference is pinned to a
commit SHA, so an update is a deliberate pull request, not a silent
drift.
