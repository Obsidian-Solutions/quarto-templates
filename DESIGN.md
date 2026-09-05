# Obsidian Solutions Design System

This file codifies the visual system of the Obsidian Solutions Quarto
template. It is an extraction of the system that already exists in
`_extensions/obsidian/` (brand.yml tokens, the SCSS themes, and the
components), not a new invention. Every value below traces to the
token files; the single source of truth for the palette is
`brand.yml`, and `tools/tokens.py` generates the per-engine token
files from it.

## 1. Atmosphere & Identity

A quiet professional-document system. Monochrome by default, dense
when the document needs it, spacious when it does not. The signature
is controlled restraint: near-black text on white, hairline rules for
structure, one accent choice per document. It is the visual language
of a consulting firm that wants the document to be taken seriously
before the logo is read.

## 2. Colour

### Palette (semantic roles, from brand.yml)

| Role | Token | Value | Contrast on white | Usage |
|------|-------|-------|-------------------|-------|
| Text/primary | primary | #121212 | 18.7:1 | Body, headings, focus ring |
| Text/secondary | secondary | #484949 | 9.0:1 (AAA) | Muted text, links, captions |
| Border/hairline | border | #cecece | decorative | Rules, table lines, separators |
| Surface/raised | surface | #f3f3f3 | on white | Panels, masthead band, callout background |
| Text/link | link | #484949 | 9.0:1 | Underlined links (same as secondary) |

Dark theme inverts the roles on a #121212 ground (primary #f2f2f2,
secondary #b8b8b8).

### Accent palette (opt-in, never the default)

plum #532a45, maroon #522b45, slate #313d47, olive #6a7a4a, crimson
#8e1537, forest #4a5032, blue #1d70b8, gold #ffdb00 and others. A
document opts into ONE accent; the house monochrome is the default.

### Rules
- Never introduce a hex not in brand.yml. Extend brand.yml first.
- The accent palette is opt-in per document; the default is monochrome.
- Contrast floors: 4.5:1 text, 3:1 large text (WCAG 2.2 AA).
- The classification marking is a full-width banner at the top of
  every web surface (HTML companion, dashboard, revealjs). The
  top-right placement is the PDF/print header rule; the web formats
  use the banner because a marking must not sit under a browser
  toolbar or fold edge.

## 3. Typography

### Scale (GOV.UK-derived, large screens)

| Level | Size | Weight | Line height | Usage |
|-------|------|--------|-------------|-------|
| Display | 48px | 700 | 50px | Page title (masthead) |
| H1 | 36px | 700 | 40px | Section headers |
| H2 | 27px | 600 | 30px | Subsection headers |
| H3 | 24px | 600 | 30px | Sub-subsection |
| Body | 19px | 400 | 25px | Default text |
| Body/s | 16px | 400 | 20px | Secondary info |
| Caption | 16px | 500 | 20px | Labels, metadata |

### Font stack
- Sans (headings): Montserrat, "Segoe UI", "Helvetica Neue", Arial
- Serif (body): "Palatino Linotype", Palatino, Georgia, "Times New Roman"
- Mono: Liberation Mono

### Rules
- Headings are Montserrat, body is serif. The editorial pairing is
  the identity. Do not swap to a generic sans for body.
- Body text never below 16px on the web.
- Numbers in data tables use tabular figures where available.

## 4. Spacing & Layout

### Base unit
5px (brand.yml spacing scale, GOV.UK-derived): 0, 5, 10, 15, 20,
25, 30, 40, 50, 60px.

### Grid
- Max content width: 1020px (govuk-width-container convention)
- Breakpoints: 640px tablet, 1024px desktop
- Two-thirds + one-third content columns at desktop

### Rules
- No magic numbers; spacing maps to the scale.
- Asymmetric spacing is intentional (optical adjustment), not accidental.

## 5. Components

### Masthead
- **Structure**: banner band (surface token) > brand mark + title + subtitle
- **Spacing**: 1.5rem vertical padding, 2rem below
- **States**: n/a (static header)
- **Accessibility**: title/subtitle dark on the off-white band
  (explicit h1 colour rule; Quarto's default near-white is overridden)

### Summary list
- **Structure**: definition list > rows (dt bold key, dd value)
- **Variants**: stacked (mobile), two-column 30/70 (desktop)
- **Spacing**: 0.75rem row padding, hairline separators
- **Accessibility**: keys bold, values wrap, hairline borders

### Inset text
- **Structure**: block with 4px left rule (primary token)
- **Spacing**: 1.5rem margin, 0.75/1rem padding
- **Accessibility**: the left rule carries meaning (guidance). Text
  also states the guidance

### Phase banner
- **Structure**: label (uppercase, secondary) + status text, hairline under
- **Spacing**: 0.75rem bottom padding, 1.5rem below
- **Accessibility**: the label is not the only cue; the status text
  states the phase

### Organisation logo
- **Structure**: 2px brand bar + name in sans
- **Spacing**: 0.5rem left padding
- **Accessibility**: the name is text (the mark is decorative)

## 6. Motion & Interaction

Minimal by design. This is a document system, not an app. Web
surfaces (HTML companion, dashboard) keep transitions to a 200-300ms
ease for interactive elements. Links underline on hover; focus shows
a visible 2-3px ring (primary token). No scroll-jacking, no entry
animations on document pages.

## 7. Depth & Surface

**Strategy: borders-only.** Structure comes from hairline rules
(#cecece) and the surface token (#f3f3f3) for the masthead band and
raised callouts. Cards and panels stay white with hairline borders.
No shadows, no rounded corners. This matches the print origin of the
system (haplines read as rules on paper).

## Known inconsistencies (extraction flags)

- The dark theme's raised surface (#1e1e1e) and hairline
  (#484949) are not in brand.yml as named tokens. They are inline
  overrides in theme-dark.scss. Candidate for consolidation.
- The accent palette lives only in brand.yml; the SCSS token file
  exposes it ($token-*) but the HTML themes do not consume the
  swatches. Candidate for exposing a documented accent mechanism.
- tabular figures are not enforced for tables on the web; the
  LaTeX booktabs path handles this natively.
- The dashboard navbar inherited Quarto's default steel-blue
  gradient (--bg-gradient). The theme overrides it to house
  monochrome (resolved in the polish pass).
- The HTML body renders at Bootstrap's default 1rem (16px), below
  the 19px body token in brand.yml. The theme now sets the token
  value (resolved in the polish pass).
- Dashboard cards inherited Bootstrap's rounded corners; the
  borders-only strategy wants radius 0 (resolved in the polish
  pass).
