-- SPDX-License-Identifier: MIT
-- typst-meta.lua
-- Expose Quarto's document and format options to the Typst show-rule
-- template.
--
-- pandoc's typst writer does not set the `numbersections` template
-- variable (verified: the LaTeX writer sets it, the typst writer
-- does not), and Quarto passes `number-sections` as a format option,
-- not as document metadata, so a template `$if(...)$` cannot see it.
-- Quarto DOES put the resolved value in metadata under
-- `section-numbering` (a list such as ["1.1.a"] when numbering is
-- on, absent when off).
--
-- Typst format options that Quarto recognizes (cover, heading-font,
-- fontsize, ...) DO land in metadata as strings, but pandoc's typst
-- writer only passes them to the template if they have known
-- template-variable shapes. Forwarding them here (under the same
-- names) makes them visible to the show-rule, so a format block like
--
--   format:
--     obsidian-typst:
--       cover: banded
--       heading-font: Arial
--       fontsize: 12pt
--
-- actually reaches the template instead of being silently dropped.
-- The same filter copies section-numbering into a boolean the show
-- rule can read, so the Typst engine honors number-sections like the
-- LaTeX formats do.

local OPTIONS = {
  cover = "cover",
  ["heading-font"] = "heading-font",
  fontsize = "fontsize",
}

function Meta(meta)
  if meta["section-numbering"] ~= nil then
    meta["numbersections"] = pandoc.MetaBool(true)
  end
  for key, target in pairs(OPTIONS) do
    if meta[key] ~= nil then
      meta[target] = meta[key]
    end
  end
  return meta
end

