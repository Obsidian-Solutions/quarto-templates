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
  - `codeql` (static analysis)
- Require signed commits
- Require linear history (squash merging)
- Require the branch to be up to date before merging
- Do not allow force pushes
- Do not allow deletions

CODEOWNERS protects the sensitive paths: review requests go to the
owner until a team exists.

## Secret scanning

In the repository settings under Code security and analysis:

- Enable secret scanning
- Enable push protection, so secrets cannot be committed in the
  first place (NCSC Secure Development: separate secret credentials
  from the code base)

## Repository secrets

The release workflow signs its commit and tag with the sole trader's
GPG key, so the private key must exist inside the runner. Store these
two secrets:

- `GPG_PRIVATE_KEY`: the ASCII-armoured private key, base64-encoded
- `GPG_PASSPHRASE`: the key passphrase

The workflow fails loudly when they are missing, so a release
baseline is never unsigned (JSP 945).

## Dependabot

The `dependabot.yml` manifest enables version updates for the GitHub
Actions. Keep them enabled. Every action reference is pinned to a
commit SHA, so an update is a deliberate pull request, not a silent
drift.
