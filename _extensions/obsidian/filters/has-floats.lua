-- SPDX-License-Identifier: MIT
-- has-floats.lua: set has-figures / has-tables so the List of
-- Tables / List of Figures pages render only for listable floats.
--
-- A table is listable when it has a caption: \listoftables lists
-- captions. In the pandoc AST the caption lives in the Table node
-- (a Caption object in pandoc 3.1.2+, a plain block list before).
-- Layout tables (invoice line items, totals) carry empty captions
-- and must not set has-tables.

local function caption_text(tbl)
  local cap = tbl.caption
  if cap == nil then
    return ""
  end
  if cap.content ~= nil then
    return pandoc.utils.stringify(cap.content)
  end
  return pandoc.utils.stringify(cap)
end

local function count(blocks, tables, figures)
  for _, b in ipairs(blocks) do
    if b.t == 'Figure' then
      figures = figures + 1
    elseif b.t == 'Table' then
      if caption_text(b) ~= '' then
        tables = tables + 1
      end
    elseif b.t == 'Div' or b.t == 'BlockQuote' then
      local t2, f2 = count(b.content, 0, 0)
      tables = tables + t2
      figures = figures + f2
    end
  end
  return tables, figures
end

function Pandoc(doc)
  local tables, figures = count(doc.blocks, 0, 0)
  doc.meta['has-figures'] = pandoc.MetaBool(figures > 0)
  doc.meta['has-tables'] = pandoc.MetaBool(tables > 0)
  return doc
end
