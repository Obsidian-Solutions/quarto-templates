#!/usr/bin/env python3
"""make-changelog.py - generate CHANGELOG.md from git history.

The version is a single source of truth: it lives in
_extensions/obsidian/_extension.yml, and this script reads it there.
The release tag, the changelog section, the SBOM version and the
version in tools/make-sbom.py all derive from that one value, so
they can never disagree.

Reads the signed release tags and the commit messages between them,
groups the commits by type prefix, and writes CHANGELOG.md. The
output is deterministic: the same history always produces the same
file, so the changelog never drifts from the commits (JSP 945 change
records).

With no tags yet, all commits fall into one section for the current
extension version. The script stops if the current version is
already tagged: bump the version in _extension.yml first.

Usage:
  make-changelog.py [--output CHANGELOG.md]
  make-changelog.py --notes     print the release section only

Stdlib only. No network access. Run it on any machine with git.
"""

import argparse
import json
import re
import subprocess
import sys
from datetime import date
from pathlib import Path
from typing import NoReturn

VERSION_RE = re.compile(r"^v?(\d+)\.(\d+)\.(\d+)$")


def git(*args: str) -> str:
    """Run git and return stdout, failing loudly on error."""
    proc = subprocess.run(["git", *args], capture_output=True, text=True, check=True)
    return proc.stdout


def release_tags() -> list[str]:
    """Return the release tags sorted newest first."""
    tags = git("tag", "-l", "--sort=-v:refname").split()
    return [t for t in tags if VERSION_RE.match(t)]


def commits_between(since: str | None, until: str) -> list[str]:
    """Return commit subjects in the range, oldest first."""
    if since:
        rng = f"{since}..{until}"
    else:
        rng = until
    return git("log", "--format=%s", "--reverse", rng).splitlines()


def section_name(version: str | None) -> str:
    if version:
        return f"## {version} - {date.today().isoformat()}"
    return "## Unreleased"


def group(commits: list[str]) -> dict[str, list[str]]:
    """Group commit subjects by the changelog category."""
    buckets: dict[str, list[str]] = {
        "Added": [],
        "Fixed": [],
        "Changed": [],
        "Removed": [],
    }
    for subject in commits:
        prefix, _, rest = subject.partition(":")
        prefix = prefix.strip().lower()
        rest = rest.strip()
        if not rest:
            continue
        if prefix == "feat":
            buckets["Added"].append(rest)
        elif prefix == "fix":
            buckets["Fixed"].append(rest)
        elif prefix in (
            "refactor",
            "build",
            "ci",
            "docs",
            "chore",
            "test",
            "ops",
            "sec",
        ):
            buckets["Changed"].append(rest)
        else:
            buckets["Changed"].append(subject)
    return {k: v for k, v in buckets.items() if v}


def render(entries: list[tuple[str | None, list[str]]]) -> str:
    """Render the changelog body: sections with grouped bullets."""
    out: list[str] = []
    for version, commits in entries:
        out.append(section_name(version))
        out.append("")
        for category, items in group(commits).items():
            out.append(f"### {category}")
            out.append("")
            for item in items:
                out.append(f"- {item}")
            out.append("")
    return "\n".join(out).rstrip() + "\n"


def bump_version(version: str, repo: Path) -> None:
    """Keep the version homes in step."""
    ext = repo / "_extensions" / "obsidian" / "_extension.yml"
    text = ext.read_text()
    text = re.sub(r"^version: .*$", f"version: {version}", text, count=1, flags=re.M)
    ext.write_text(text)

    sbom_script = repo / "tools" / "make-sbom.py"
    text = sbom_script.read_text()
    text = re.sub(r'"versionInfo": ".*"', f'"versionInfo": "{version}"', text, count=1)
    sbom_script.write_text(text)

    subprocess.run([sys.executable, str(repo / "tools" / "make-sbom.py")], check=True)


def extension_version(repo: Path) -> str:
    """Read the version from the extension manifest, the single truth."""
    text = (repo / "_extensions" / "obsidian" / "_extension.yml").read_text()
    match = re.search(r"^version:\s*(\S+)$", text, flags=re.M)
    if not match:
        parser_error("no version line in _extension.yml")
    return match.group(1)


def parser_error(message: str) -> NoReturn:
    """Print an error and exit non-zero."""
    print(f"make-changelog.py: error: {message}", file=sys.stderr)
    sys.exit(2)


def main() -> int:
    parser = argparse.ArgumentParser(description=(__doc__ or "").splitlines()[0])
    parser.add_argument("--output", default="CHANGELOG.md")
    parser.add_argument(
        "--notes", action="store_true", help="print the release section only"
    )
    args = parser.parse_args()

    repo = Path(git("rev-parse", "--show-toplevel").strip())
    output = Path(args.output)
    if not output.is_absolute():
        output = repo / output

    version = extension_version(repo)
    if not VERSION_RE.match(version):
        parser_error(f"extension version {version} is not X.Y.Z")

    tags = release_tags()
    if version in [t.lstrip("v") for t in tags]:
        parser_error(
            f"version {version} is already tagged; bump the version in "
            "_extension.yml before the next release"
        )

    entries: list[tuple[str | None, list[str]]] = []
    entries.append((version, commits_between(tags[0] if tags else None, "HEAD")))

    for i in range(len(tags)):
        since = tags[i + 1] if i + 1 < len(tags) else None
        entries.append((tags[i].lstrip("v"), commits_between(since, tags[i])))

    if args.notes:
        print(render(entries[:1]).strip())
        return 0

    header = (
        "# Changelog\n"
        "\n"
        "This file records the notable changes to each release. The format "
        "follows Keep a Changelog, and the version numbers follow Semantic "
        "Versioning. The file is generated by tools/make-changelog.py from "
        "the signed release tags and the commit history. Do not edit it by "
        "hand; run the release procedure in CONTRIBUTING.md instead.\n"
    )
    output.write_text(header + "\n" + render(entries))

    bump_version(version, repo)

    print(f"wrote {output.relative_to(repo)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
