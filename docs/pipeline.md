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

## Digital Signing

### What is a signing certificate?

A signing certificate is an X.509 digital identity document. It
proves the signer is who they claim to be. PDF readers display the
signer name and a validity chain when a signed document is opened.

Two files are needed:

- **Certificate** (`SIGNING_CERT`): the public identity. PEM format.
  Contains the signer name, organisation, validity dates, and the
  issuing Certificate Authority (CA).
- **Private key** (`SIGNING_KEY`): proves ownership of the certificate.
  PEM format. Keep this secret. Never commit it to a repository.

Together, these create a PAdES B-LT electronic signature (the European
standard for long-term PDF signing, defined in ETSI EN 319 142).

### Self-signed certificates (testing and internal use)

A self-signed certificate is one where the signer is also the CA.
No external authority vouches for it. PDF readers show "unknown
signer" but the signature is cryptographically valid.

Generate a self-signed certificate for testing:

```bash
# Generate a 4096-bit RSA key pair
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem \
  -days 365 -nodes \
  -subj "/CN=Obsidian Solutions/O=Obsidian Solutions/C=GB"

# Verify the certificate
openssl x509 -in cert.pem -text -noout
```

This creates two files:

- `cert.pem` — the certificate (set as `SIGNING_CERT`)
- `key.pem` — the private key (set as `SIGNING_KEY`)

### CA-signed certificates (production use)

For production documents seen by external parties, use a certificate
issued by a trusted Certificate Authority. The CA verifies your
identity and their root certificate is pre-installed in PDF readers
and operating systems.

Options for obtaining a CA-signed certificate:

| Provider | Type | Use case |
|----------|------|----------|
| Sectigo | Organisation Validation (OV) | Business documents |
| DigiCert | Extended Validation (EV) | High-assurance documents |
| Let's Encrypt | Domain Validation (DV) | Not suitable for PDF signing (only TLS) |
| Self-hosted CA | Internal | Organisations with their own PKI |

For government use, certificates from the UK Government's List of
Approved Accreditation Services or similar national schemes may be
required.

### Hardware security modules (PKCS#11)

For the highest assurance, store the private key on a hardware
device (smart card, USB token, HSM). pyHanko supports PKCS#11
devices via the `pkcs11` extra:

```bash
pip install "pyHanko[pkcs11]"
```

Set the PKCS#11 PIN:

```bash
export SIGNING_PIN=1234
```

The sign.sh script passes the PIN to pyHanko. The certificate and
key paths in `SIGNING_CERT` and `SIGNING_KEY` should point to the
PEM exports of the certificate stored on the device.

### Verifying a signed document

```bash
# Check signature with pyHanko
pyhanko validate --signing-cert cert.pem document.pdf

# Or use veraPDF for PDF/A signature validation
verapdf --level 2 document.pdf
```

PDF readers (Adobe Acrobat, Foxit, Okular) display signature
details when a signed document is opened.

### Signature fields

The pipeline creates a visible signature field. By default:

- **Field name**: `Obsidian Solutions` (set via `SIGNING_FIELD`)
- **Reason**: `Document signed by Obsidian Solutions` (set via `SIGNING_REASON`)
- **Position**: determined by the Lua filter in the template

To create an invisible signature (no visual mark), modify the
form-fields.lua filter to set `/Ff 12` (invisible flag).

## Installation

### Python packages (recommended)

The pipeline uses `uv` for Python dependency management. First run
of any script installs dependencies automatically into the project.

```bash
# Dependencies are in scripts/pyproject.toml
# First run of render.sh handles installation automatically
# Or install manually:
cd scripts && uv sync
```

### Python packages (manual)

```bash
pip install pyHanko[pkcs11] pypdf pyyaml pymupdf
```

### System packages

Debian / Ubuntu:

```bash
sudo apt install qpdf ghostscript verapdf
```

Fedora / RHEL:

```bash
sudo dnf install qpdf ghostscript verapdf
```

Arch Linux:

```bash
sudo pacman -S qpdf ghostscript verapdf
```

openSUSE:

```bash
sudo zypper install qpdf ghostscript verapdf
```

macOS:

```bash
brew install qpdf ghostscript vera-pdf
```

### Detecting your package manager

The pipeline scripts do not install system packages for you. Check
which package manager is available:

| Manager | Command | Distros |
|---------|---------|---------|
| `apt` | `sudo apt install` | Debian, Ubuntu, Mint, Pop!_OS |
| `dnf` | `sudo dnf install` | Fedora, RHEL, CentOS, Rocky, Alma |
| `pacman` | `sudo pacman -S` | Arch, Manjaro, EndeavourOS |
| `zypper` | `sudo zypper install` | openSUSE Leap, Tumbleweed |
| `brew` | `brew install` | macOS, Linux (Homebrew) |

## Troubleshooting

### Validation fails after render

The most common cause is missing XMP metadata. Run `fix-metadata.sh`
first. If that fails, run `convert-pdf-a.sh` for a full re-conversion.

### Signing is skipped

Check that `SIGNING_CERT` and `SIGNING_KEY` are set and the files
exist. Install pyHanko with `cd scripts && uv sync`.

### Encryption is skipped

Check that qpdf is installed: `qpdf --version`. Install with
`sudo apt install qpdf` (Debian), `sudo dnf install qpdf` (Fedora),
or `sudo pacman -S qpdf` (Arch).

### Forms do not render

Ensure `forms: true` is in the front matter and the document uses
PDF output format. Forms are not supported in HTML or DOCX.

## Licence

MIT
