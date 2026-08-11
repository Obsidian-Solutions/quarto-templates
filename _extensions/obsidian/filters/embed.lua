-- embed.lua
-- Emits \embedfile commands for the PDF format from front-matter
-- `attach:` entries, so the controlled PDF carries its own source
-- and any supporting files (PDF/A-4f self-containment).
--
-- Front matter:
--   attach:
--     - source: example.qmd
--       description: Source document
--       mimetype: text/markdown
--
-- The listed files must be present in the working directory at
-- render time (add them to `format-resources` in _extension.yml).
-- LaTeX's embedfile package writes the AFRelationship, Subtype and
-- Desc keys that verapdf requires, which qpdf's --add-attachment
-- does not.

local function stringify(v)
  return pandoc.utils.stringify(v or '')
end

function Pandoc(doc)
  if FORMAT ~= 'latex' then
    return doc
  end
  local attach = doc.meta['attach']
  if not attach then
    return doc
  end

  local cmds = {}
  -- The value is a pandoc MetaList (t == 'MetaList') or a plain Lua
  -- table depending on how Quarto passes the front matter. Handle both.
  local entries = {}
  if type(attach) == 'table' and attach.t == 'MetaList' then
    entries = attach
  elseif type(attach) == 'table' then
    entries = attach
  else
    entries = { attach }
  end
  for _, entry in ipairs(entries) do
      local src = stringify(entry['source'])
      if src ~= '' then
        local desc = stringify(entry['description'])
        local mime = stringify(entry['mimetype'])
        local opts = {}
        if desc ~= '' then table.insert(opts, 'desc={' .. desc .. '}') end
        if mime ~= '' then table.insert(opts, 'mimetype={' .. mime .. '}') end
        table.insert(opts, 'afrelationship={Source}')
        table.insert(cmds, '\\embedfile[' .. table.concat(opts, ',') .. ']{' .. src .. '}')
      end
    end

  if #cmds > 0 then
    local block = pandoc.RawBlock('latex', table.concat(cmds, '\n'))
    -- \embedfile must execute at \begin{document}; the preamble is
    -- not reachable from a filter, so run it at the top of the body.
    table.insert(doc.blocks, 1, block)
  end
  return doc
end
