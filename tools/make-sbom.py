#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""make-sbom.py - generate sbom.spdx.json (SPDX 2.3) for the extension.

Lists the third-party components the template bundles or depends on,
with their licences and pinned origins. This is the supply-chain
record required by the UK Software Security Code principle 1.2 and
NIST SSDF PW.4.1: understand software composition and assess
third-party risk.

Stdlib only (Python 3). Deterministic: package order is sorted and
the document creation date comes from the last commit, so the CI
freshness check (regenerate, then `git diff --exit-code`) is stable.

Usage: python3 tools/make-sbom.py [output.json]
"""

import json
import subprocess
import sys

# SPDX 2.3 JSON. Package fields follow the SPDX spec; keep additions
# minimal so the file stays machine-parseable by standard tooling.
SPDX_VERSION = "SPDX-2.3"

COMPONENTS = [
    {
        "name": "obsidian-quarto-templates",
        "SPDXID": "SPDXRef-Package-obsidian",
        "versionInfo": "3.6.0",
        "supplier": "Organization: Obsidian Solutions",
        "downloadLocation": "https://github.com/Obsidian-Solutions/quarto-templates",
        "licenseConcluded": "MIT",
        "copyrightText": "Copyright (c) 2026 Matthew Barker",
    },
    {
        "name": "numeric.csl",
        "SPDXID": "SPDXRef-Package-numeric-csl",
        "versionInfo": "IEEE Reference Guide version 11.29.2023",
        "supplier": "Person: Michael Berkowitz",
        "downloadLocation": "https://www.zotero.org/styles/ieee",
        "licenseConcluded": "CC-BY-SA-3.0",
        "copyrightText": "See NOTICE",
    },
    {
        "name": "obsidian-reference.docx",
        "SPDXID": "SPDXRef-Package-reference-docx",
        "versionInfo": "bundled",
        "supplier": "Organization: Posit Software, PBC",
        "downloadLocation": "https://github.com/quarto-dev/quarto-cli",
        "licenseConcluded": "MIT",
        "copyrightText": "Derived from the Quarto default reference document; see NOTICE",
    },
    {
        "name": "obsidian-reference.pptx",
        "SPDXID": "SPDXRef-Package-reference-pptx",
        "versionInfo": "bundled",
        "supplier": "Organization: Posit Software, PBC",
        "downloadLocation": "https://github.com/quarto-dev/quarto-cli",
        "licenseConcluded": "MIT",
        "copyrightText": "Derived from the Quarto default reference document; see NOTICE",
    },
    {
        "name": "Montserrat",
        "SPDXID": "SPDXRef-Package-montserrat",
        "versionInfo": "commit 555facfb2a18c72c3c0380f0d9c0f060453a9058",
        "supplier": "Person: Julieta Ulanovsky",
        "downloadLocation": "https://raw.githubusercontent.com/JulietaUla/Montserrat/555facfb2a18c72c3c0380f0d9c0f060453a9058/fonts/ttf/",
        "licenseConcluded": "OFL-1.1",
        "copyrightText": "Copyright (c) Julieta Ulanovsky; see NOTICE",
    },
    {
        "name": "TeX Gyre Pagella",
        "SPDXID": "SPDXRef-Package-tex-gyre-pagella",
        "versionInfo": "from TeX Live tex-gyre",
        "supplier": "Organization: GUST",
        "downloadLocation": "https://www.gust.org.pl/projects/e-foundry/tex-gyre",
        "licenseConcluded": "GFL-1.0",
        "copyrightText": "See NOTICE",
    },
    {
        "name": "Liberation Mono",
        "SPDXID": "SPDXRef-Package-liberation-mono",
        "versionInfo": "from distro fonts-liberation",
        "supplier": "Organization: Red Hat",
        "downloadLocation": "https://github.com/liberationfonts/liberation-fonts",
        "licenseConcluded": "OFL-1.1",
        "copyrightText": "See NOTICE",
    },
    {
        "name": "actions/checkout",
        "SPDXID": "SPDXRef-Package-actions-checkout",
        "versionInfo": "3d3c42e5aac5ba805825da76410c181273ba90b1",
        "supplier": "Organization: GitHub",
        "downloadLocation": "https://github.com/actions/checkout",
        "licenseConcluded": "MIT",
        "copyrightText": "Copyright (c) GitHub",
    },
    {
        "name": "quarto-dev/quarto-actions",
        "SPDXID": "SPDXRef-Package-quarto-actions",
        "versionInfo": "8a96df13519ee81fd526f2dfca5962811136661b",
        "supplier": "Organization: Quarto",
        "downloadLocation": "https://github.com/quarto-dev/quarto-actions",
        "licenseConcluded": "MIT",
        "copyrightText": "Copyright (c) Quarto",
    },
    {
        "name": "actions/configure-pages",
        "SPDXID": "SPDXRef-Package-configure-pages",
        "versionInfo": "45bfe0192ca1faeb007ade9deae92b16b8254a0d",
        "supplier": "Organization: GitHub",
        "downloadLocation": "https://github.com/actions/configure-pages",
        "licenseConcluded": "MIT",
        "copyrightText": "Copyright (c) GitHub",
    },
    {
        "name": "actions/upload-pages-artifact",
        "SPDXID": "SPDXRef-Package-upload-pages-artifact",
        "versionInfo": "fc324d3547104276b827a68afc52ff2a11cc49c9",
        "supplier": "Organization: GitHub",
        "downloadLocation": "https://github.com/actions/upload-pages-artifact",
        "licenseConcluded": "MIT",
        "copyrightText": "Copyright (c) GitHub",
    },
    {
        "name": "actions/deploy-pages",
        "SPDXID": "SPDXRef-Package-deploy-pages",
        "versionInfo": "cd2ce8fcbc39b97be8ca5fce6e763baed58fa128",
        "supplier": "Organization: GitHub",
        "downloadLocation": "https://github.com/actions/deploy-pages",
        "licenseConcluded": "MIT",
        "copyrightText": "Copyright (c) GitHub",
    },
    {
        "name": "astral-sh/setup-uv",
        "SPDXID": "SPDXRef-Package-setup-uv",
        "versionInfo": "20cfd1bf945f4377ade1205e4dbc17946fc9a30d (v10.0.1)",
        "supplier": "Organization: Astral",
        "downloadLocation": "https://github.com/astral-sh/setup-uv",
        "licenseConcluded": "MIT",
        "copyrightText": "Copyright (c) Astral",
    },
    {
        "name": "github/codeql-action",
        "SPDXID": "SPDXRef-Package-codeql-action",
        "versionInfo": "5595ccaf912efad79be6eef63a5619ff05969be3",
        "supplier": "Organization: GitHub",
        "downloadLocation": "https://github.com/github/codeql-action",
        "licenseConcluded": "MIT",
        "copyrightText": "Copyright (c) GitHub",
    },
    {
        "name": "Obsidian-Solutions/.github (attest workflow)",
        "SPDXID": "SPDXRef-Package-obsidian-github-attest",
        "versionInfo": "121780f0d587ca5516e5d29ae8dafcdc8348a5ad",
        "supplier": "Organization: Obsidian Solutions",
        "downloadLocation": "https://github.com/Obsidian-Solutions/.github",
        "licenseConcluded": "MIT",
        "copyrightText": "Copyright (c) Obsidian Solutions",
    },
    {
        "name": "Obsidian-Solutions/.github (commit-format workflow)",
        "SPDXID": "SPDXRef-Package-obsidian-github-commit-format",
        "versionInfo": "f8db4ab90072c80a0e9abb3a8ac3e288823070fc",
        "supplier": "Organization: Obsidian Solutions",
        "downloadLocation": "https://github.com/Obsidian-Solutions/.github",
        "licenseConcluded": "MIT",
        "copyrightText": "Copyright (c) Obsidian Solutions",
    },
    {
        "name": "pikepdf",
        "SPDXID": "SPDXRef-Package-pikepdf",
        "versionInfo": ">=10.11.0 (requirements.txt)",
        "supplier": "Organization: PyPI",
        "downloadLocation": "https://pypi.org/project/pikepdf/",
        "licenseConcluded": "MPL-2.0",
        "copyrightText": "See NOTICE",
    },
]


def git_commit() -> str:
    """Resolve the current commit SHA, for the document namespace."""
    out = subprocess.run(
        ["git", "rev-parse", "HEAD"], capture_output=True, text=True, check=False
    )
    return out.stdout.strip() or "unknown"


def git_committer_date() -> str:
    """Committer date of HEAD, the deterministic creation timestamp."""
    out = subprocess.run(
        ["git", "log", "-1", "--format=%cI"],
        capture_output=True,
        text=True,
        check=False,
    )
    return out.stdout.strip() or "1970-01-01T00:00:00Z"


def build_document(commit: str, created: str) -> dict:
    packages = sorted(COMPONENTS, key=lambda p: p["name"])
    relationships = [
        {
            "spdxElementId": "SPDXRef-DOCUMENT",
            "relationshipType": "DESCRIBES",
            "relatedSpdxElement": "SPDXRef-Package-obsidian",
        },
    ]
    for p in packages:
        if p["SPDXID"] != "SPDXRef-Package-obsidian":
            relationships.append(
                {
                    "spdxElementId": "SPDXRef-Package-obsidian",
                    "relationshipType": "CONTAINS",
                    "relatedSpdxElement": p["SPDXID"],
                }
            )
    return {
        "spdxVersion": SPDX_VERSION,
        "dataLicense": "CC0-1.0",
        "SPDXID": "SPDXRef-DOCUMENT",
        "name": "obsidian-quarto-templates",
        "documentNamespace": (
            "https://github.com/Obsidian-Solutions/quarto-templates/sbom/spdx/" + commit
        ),
        "creationInfo": {
            "created": created,
            "creators": [
                "Tool: tools/make-sbom.py",
                "Organization: Obsidian Solutions",
            ],
        },
        "packages": packages,
        "relationships": relationships,
    }


def main() -> int:
    out_path = sys.argv[1] if len(sys.argv) > 1 else "sbom.spdx.json"
    doc = build_document(git_commit(), git_committer_date())
    with open(out_path, "w", encoding="utf-8") as fh:
        json.dump(doc, fh, indent=2, sort_keys=True)
        fh.write("\n")
    print(f"wrote {out_path} ({len(doc['packages'])} packages)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
