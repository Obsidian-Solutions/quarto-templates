-- classification.lua
-- Injects a classification banner into the HTML, revealjs and DOCX
-- companions so every delivered copy carries the same marking as
-- the PDF. Fires only for non-LaTeX output; the PDF carries the
-- marking in its running header.
--
-- Banner text: "DRAFT – Commercial in Confidence" from the front
-- matter fields `draft` and `confidentiality`.

local plain_formats = { html = true, revealjs = true, docx = true }

function Pandoc(doc)
  -- FORMAT is pandoc's writer-format global; PANDOC_WRITER_OPTIONS
  -- is not populated under Quarto.
  if not plain_formats[FORMAT] then
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
    table.insert(parts, 'DRAFT')
  end
  if confidentiality ~= '' then
    table.insert(parts, pandoc.utils.stringify(meta['confidentiality']))
  end
  local text = table.concat(parts, ' \226\128\147 ')  -- en dash
  local block
  if FORMAT == 'docx' then
    -- A Div with custom-style maps to a named paragraph style in
    -- the reference document (pandoc docx writer).
    local div = pandoc.Div({ pandoc.Para({ pandoc.Str(text) }) })
    div.attributes['custom-style'] = 'ClassificationBanner'
    block = div
  else
    block = pandoc.RawBlock(
      'html',
      '<div class="obsidian-classification"><span class="status">'
        .. text .. '</span></div>'
    )
  end
  table.insert(doc.blocks, 1, block)
  return doc
end
