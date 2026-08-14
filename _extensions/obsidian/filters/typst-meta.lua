-- SPDX-License-Identifier: MIT
-- typst-meta.lua
-- Expose Quarto's document options to the Typst show-rule template.
--
-- pandoc's typst writer does not set the `numbersections` template
-- variable (verified: the LaTeX writer sets it, the typst writer
-- does not), and Quarto passes `number-sections` as a format option,
-- not as document metadata, so a template `$if(...)$` cannot see it.
--
-- Quarto DOES put the resolved value in metadata under
-- `section-numbering` (a list such as ["1.1.a"] when numbering is
-- on, absent when off). This filter copies that into a boolean the
-- show-rule template can read, so the Typst engine honors the
-- document's number-sections flag like the LaTeX formats do.

function Meta(meta)
  if meta["section-numbering"] ~= nil then
    meta["numbersections"] = pandoc.MetaBool(true)
  end
  return meta
end
