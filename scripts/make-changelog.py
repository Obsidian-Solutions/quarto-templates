#!/usr/bin/env python3
"""make-changelog.py - generate CHANGELOG.md from git history.

Reads the signed release tags and the commit messages between them,
groups the commits by type prefix, and writes CHANGELOG.md. The
output is deterministic: the same history always produces the same
file, so the changelog never drifts from the commits (JSP 945 change
records).

With no tags, all commits fall into one section. With --version, the
top section carries that version and today's date, and the version
homes stay in step: _extension.yml, scripts/make-sbom.py, and the
regenerated SBOM. Without --version, the top section is Unreleased.

Usage:
  make-changelog.py [--version X.Y.Z] [--output CHANGELOG.md]

Stdlib only. No network access. Run it on any machine with git.
"""

import argparse
import json
import re
import subprocess
import sys
from datetime import date
from pathlib import Path

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

    sbom_script = repo / "scripts" / "make-sbom.py"
    text = sbom_script.read_text()
    text = re.sub(r'"versionInfo": ".*"', f'"versionInfo": "{version}"', text, count=1)
    sbom_script.write_text(text)

    subprocess.run([sys.executable, str(repo / "scripts" / "make-sbom.py")], check=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=(__doc__ or "").splitlines()[0])
    parser.add_argument("--version", help="release version, for example 3.4.0")
    parser.add_argument("--output", default="CHANGELOG.md")
    args = parser.parse_args()

    repo = Path(git("rev-parse", "--show-toplevel").strip())
    output = Path(args.output)
    if not output.is_absolute():
        output = repo / output

    if args.version and not VERSION_RE.match(args.version):
        parser.error(f"version {args.version} is not X.Y.Z")

    tags = release_tags()
    entries: list[tuple[str | None, list[str]]] = []

    if args.version:
        entries.append(
            (args.version, commits_between(tags[0] if tags else None, "HEAD"))
        )
    else:
        entries.append((None, commits_between(tags[0] if tags else None, "HEAD")))

    for i in range(len(tags)):
        since = tags[i + 1] if i + 1 < len(tags) else None
        entries.append((tags[i].lstrip("v"), commits_between(since, tags[i])))

    header = (
        "# Changelog\n"
        "\n"
        "This file records the notable changes to each release. The format "
        "follows Keep a Changelog, and the version numbers follow Semantic "
        "Versioning. The file is generated by scripts/make-changelog.py from "
        "the signed release tags and the commit history. Do not edit it by "
        "hand; run the release workflow instead.\n"
    )
    output.write_text(header + "\n" + render(entries))

    if args.version:
        bump_version(args.version, repo)

    print(f"wrote {output.relative_to(repo)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
