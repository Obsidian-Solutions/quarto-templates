#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# fill_forms.py — Fill PDF form fields from YAML data.
#
# Usage: uv run --project scripts/ python3 scripts/fill_forms.py input.pdf data.yaml output.pdf
# Or via wrapper: scripts/fill-forms.py input.pdf data.yaml output.pdf [--interactive]
#
# data.yaml format:
#   field-name: "value"
#   checkbox-name: true
#   dropdown-name: "option"
#
# Flags:
#   --interactive   Keep the form editable (default: flatten)
#
# Dependencies managed by scripts/pyproject.toml via uv.

"""Fill AcroForm fields in a PDF from a YAML data file."""

import argparse
import sys
from pathlib import Path

import yaml
from pypdf import PdfReader, PdfWriter
from pypdf.generic import (
    NameObject,
    NumberObject,
    TextStringObject,
)


def fill_form(
    input_path: str, data_path: str, output_path: str, flatten: bool = True
) -> None:
    """Fill form fields and optionally flatten."""
    reader = PdfReader(input_path)
    writer = PdfWriter()

    # Clone all pages
    writer.append(reader)

    # Load data
    with open(data_path, "r") as f:
        data = yaml.safe_load(f) or {}

    # Fill fields
    for page_num in range(len(writer.pages)):
        page = writer.pages[page_num]
        if "/Annots" not in page:
            continue

        for annot in page["/Annots"]:
            obj = annot.get_object()
            field_name = obj.get("/T")
            if field_name is None:
                continue

            field_name = str(field_name)
            if field_name not in data:
                continue

            value = data[field_name]

            # Handle different field types
            field_type = obj.get("/FT", "")

            if field_type == "/Btn":
                # Checkbox or radio button
                if isinstance(value, bool):
                    if value:
                        obj.update({NameObject("/V"): NameObject("/Yes")})
                        obj.update({NameObject("/AS"): NameObject("/Yes")})
                    else:
                        obj.update({NameObject("/V"): NameObject("/Off")})
                        obj.update({NameObject("/AS"): NameObject("/Off")})
                elif isinstance(value, str):
                    obj.update({NameObject("/V"): NameObject(f"/{value}")})
                    obj.update({NameObject("/AS"): NameObject(f"/{value}")})
            elif field_type == "/Ch":
                # Choice field (dropdown or listbox)
                obj.update({NameObject("/V"): TextStringObject(str(value))})
            else:
                # Text field
                obj.update({NameObject("/V"): TextStringObject(str(value))})

            # Mark as modified
            obj.update({NameObject("/Ff"): NumberObject(1)})

            if flatten:
                # Add appearance stream so the value renders
                writer.update_page_form_field_values(
                    writer.pages[page_num], {field_name: str(value)}
                )

    # Write output
    with open(output_path, "wb") as f:
        writer.write(f)

    print(f"fill-forms.py: filled {len(data)} fields → {output_path}", file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(description="Fill PDF form fields from YAML data")
    parser.add_argument("input", help="Input PDF with form fields")
    parser.add_argument("data", help="YAML file with field values")
    parser.add_argument("output", help="Output PDF path")
    parser.add_argument(
        "--interactive",
        action="store_true",
        help="Keep form editable (default: flatten)",
    )
    args = parser.parse_args()

    if not Path(args.input).exists():
        print(f"fill-forms.py: {args.input} not found", file=sys.stderr)
        sys.exit(1)

    if not Path(args.data).exists():
        print(f"fill-forms.py: {args.data} not found", file=sys.stderr)
        sys.exit(1)

    fill_form(args.input, args.data, args.output, flatten=not args.interactive)


if __name__ == "__main__":
    main()
