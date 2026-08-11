-- classification.lua
-- Injects a classification banner into the HTML and revealjs
-- companions so the reading copy carries the same marking as the
-- PDF. Fires only for HTML-family output; the PDF carries the
-- marking in its running header.
--
-- Banner text: "DRAFT – Commercial in Confidence" from the front
-- matter fields `draft` and `confidentiality`.

local html_formats = { html = true, revealjs = true }

function Pandoc(doc)
  -- FORMAT is pandoc's writer-format global; PANDOC_WRITER_OPTIONS
  -- is not populated under Quarto.
  if not html_formats[FORMAT] then
    return doc
  end
  local meta = doc.meta
  local confidentiality = pandoc.utils.stringify(meta['confidentiality'] or '')
  local draft = pandoc.utils.stringify(meta['draft'] or '')
  if confidentiality == '' and draft == '' then
    return doc
  end
  local parts = {}
  if draft ~= '' and draft ~= 'false' then
    table.insert(parts, '<span class="status">DRAFT</span>')
  end
  if confidentiality ~= '' then
    table.insert(parts, pandoc.utils.stringify(meta['confidentiality']))
  end
  local banner = pandoc.RawBlock(
    'html',
    '<div class="obsidian-classification">' .. table.concat(parts, ' &ndash; ') .. '</div>'
  )
  table.insert(doc.blocks, 1, banner)
  return doc
end
