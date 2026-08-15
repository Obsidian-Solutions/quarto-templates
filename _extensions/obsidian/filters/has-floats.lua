-- SPDX-License-Identifier: MIT
-- has-floats.lua: set has-figures / has-tables so the List of
-- Tables / List of Figures pages render only for listable floats.
--
-- A table is listable when it has a caption (\listoftables lists
-- captions). In the Quarto pipeline the caption never lands in the
-- Table node: it becomes a sibling text block, and the wrapper shape
-- is Div > [ Div > TEXT, Div > TABLE ]. A captionless layout table
-- (memo heading block, agenda details) is a bare Table with no
-- wrapper. Count a Table when its enclosing Div also contains a text
-- block somewhere in the same wrapper subtree.

local function has_text(blocks)
  for _, b in ipairs(blocks) do
    if b.t == 'Plain' or b.t == 'Para' then
      return true
    elseif b.t == 'Div' or b.t == 'BlockQuote' then
      if has_text(b.content) then return true end
    end
  end
  return false
end

local function count(blocks, tables, figures)
  for _, b in ipairs(blocks) do
    if b.t == 'Figure' then
      figures = figures + 1
    elseif b.t == 'Div' or b.t == 'BlockQuote' then
      -- Does this wrapper contain both a table and a text block
      -- anywhere inside? If so the tables here are captioned.
      local text_inside = has_text(b.content)
      local function count_tables(bs)
        local n = 0
        for _, x in ipairs(bs) do
          if x.t == 'Table' then
            n = n + 1
          elseif x.t == 'Div' or x.t == 'BlockQuote' then
            n = n + count_tables(x.content)
          end
        end
        return n
      end
      local nt = count_tables(b.content)
      if nt > 0 and text_inside then
        tables = tables + nt
      end
      local nf = 0
      local function count_figs(bs)
        for _, x in ipairs(bs) do
          if x.t == 'Figure' then nf = nf + 1
          elseif x.t == 'Div' or x.t == 'BlockQuote' then count_figs(x.content) end
        end
      end
      count_figs(b.content)
      figures = figures + nf
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
