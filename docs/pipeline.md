# Render Pipeline

The Obsidian Solutions render pipeline is an intelligent, metadata-driven
system. Document front matter controls validation, signing, encryption,
and format compliance. No manual steps are required.

## Pipeline Stages

```
render → validate → fix-metadata → convert-pdf-a → sign → encrypt
```

Each stage is conditional. The pipeline reads YAML front matter and
skips stages that do not apply.

### 1. Render

Quarto renders the `.qmd` to PDF using LuaLaTeX or Typst. The engine
choice depends on the document type and configuration.

### 2. Validate

veraPDF checks the PDF against the declared standard (PDF/A-2b, PDF/A-4f,
or PDF/UA-1). The exit code gates the build: a non-compliant PDF
triggers the fix stages.

### 3. Fix Metadata

If validation fails on XMP metadata only (missing mandatory fields,
wrong encoding), veraPDF's fixer corrects the metadata without
re-rendering. This is the lightest fix.

### 4. Convert PDF/A

If validation fails on content issues (incorrect colour space,
font embedding), Ghostscript re-renders the PDF to the target standard.
This is heavier and may lose some fidelity.

### 5. Sign

pyHanko applies a PAdES B-LT visible signature. The certificate and
key are read from environment variables. This stage is skipped when
credentials are not available.

### 6. Encrypt

qpdf applies AES-256 encryption. The owner password is generated
randomly if not set. The user password defaults to empty (viewable
without authentication).

## Metadata Keys

| Key | Values | Effect |
|-----|--------|--------|
| `pdf-standard` | `pdfa-2b`, `pdfa-4f`, `pdfua-1` | Triggers validation and auto-fix |
| `sign` | `true`/`false` | Triggers PAdES signing |
| `encrypt` | `true`/`false` | Triggers AES-256 encryption |
| `classification` | `OFFICIAL`, `OFFICIAL-SENSITIVE`, `SECRET`, `TOP SECRET` | Auto-sets security defaults |
| `gscp` | `true`/`false` | Enables GSCP classification gate |
| `forms` | `true`/`false` | Enables form field rendering |
| `qr` | `true`/`false` | Enables QR code rendering |

## Classification Security Defaults

When `gscp: true` and a classification is set, the pipeline auto-enables
security features:

| Classification | Validate | Encrypt | Sign | PDF Standard |
|---------------|----------|---------|------|-------------|
| OFFICIAL | Yes | No | No | PDF/A-2b |
| OFFICIAL-SENSITIVE | Yes | Yes (AES-256) | Yes (PAdES B-LT) | PDF/A-4f |
| SECRET | Yes | Yes (AES-256) | Yes (PAdES B-LT) | PDF/A-4f |
| TOP SECRET | Yes | Yes (AES-256) | Yes (PAdES B-LT) | PDF/A-4f |

Note: SECRET and TOP SECRET documents require additional physical
security measures beyond what the template system can enforce.

## Usage

### Automatic (recommended)

```bash
scripts/render.sh document.qmd
```

The pipeline reads metadata from the front matter and runs only the
relevant stages.

### Individual scripts

```bash
# Validate only
scripts/validate.sh document.pdf --standard pdfa-4f

# Sign only
SIGNING_CERT=cert.pem SIGNING_KEY=key.pem scripts/sign.sh document.pdf

# Encrypt only
scripts/encrypt.sh document.pdf

# Fill forms
python3 scripts/fill-forms.py form.pdf data.yaml filled.pdf
```

## Installation

### Python packages

```bash
pip install pyHanko[pkcs11] pypdf pyyaml pymupdf
```

### System packages (Debian/Ubuntu)

```bash
sudo apt install qpdf ghostscript verapdf
```

### macOS

```bash
brew install qpdf ghostscript vera-pdf
```

## Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `SIGNING_CERT` | Path to X.509 certificate (PEM) | None (skips signing) |
| `SIGNING_KEY` | Path to private key (PEM) | None (skips signing) |
| `SIGNING_FIELD` | Signature field name | `Obsidian Solutions` |
| `SIGNING_REASON` | Signature reason | `Document signed by Obsidian Solutions` |
| `QPDF_OWNER_PASSWORD` | Owner password for encryption | Random 16-char |
| `QPDF_USER_PASSWORD` | User password for encryption | Empty (viewable) |
| `QPDF_PRINT` | Print permission | `full` |
| `QPDF_EXTRACT` | Extract permission | `y` |
| `QPDF_MODIFY` | Modify permission | `n` |

## Troubleshooting

### Validation fails after render

The most common cause is missing XMP metadata. Run `fix-metadata.sh`
first. If that fails, run `convert-pdf-a.sh` for a full re-conversion.

### Signing is skipped

Check that `SIGNING_CERT` and `SIGNING_KEY` are set and the files
exist. Install pyHanko with `pip install pyHanko[pkcs11]`.

### Encryption is skipped

Check that qpdf is installed: `qpdf --version`. Install with
`sudo apt install qpdf`.

### Forms do not render

Ensure `forms: true` is in the front matter and the document uses
PDF output format. Forms are not supported in HTML or DOCX.

## Licence

MIT
