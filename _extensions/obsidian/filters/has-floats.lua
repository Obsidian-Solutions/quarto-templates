-- SPDX-License-Identifier: MIT
-- has-floats.lua
-- Sets `has-figures` and `has-tables` metadata flags so the toc.tex
-- partial can emit List of Figures / List of Tables only when the
-- document actually contains any. Without this, the template renders
-- empty list pages for figure-free documents.

function Pandoc(doc)
  local figures = 0
  local tables = 0
  local function walk(blocks)
    for _, b in ipairs(blocks) do
      if b.t == 'Figure' then
        figures = figures + 1
      elseif b.t == 'Table' then
        tables = tables + 1
      elseif b.t == 'Div' or b.t == 'BlockQuote' then
        walk(b.content)
      end
    end
  end
  walk(doc.blocks)
  doc.meta['has-figures'] = pandoc.MetaBool(figures > 0)
  doc.meta['has-tables'] = pandoc.MetaBool(tables > 0)
  return doc
end
