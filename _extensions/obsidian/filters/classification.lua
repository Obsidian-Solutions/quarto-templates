-- SPDX-License-Identifier: MIT
-- classification.lua
-- Injects a classification banner into the HTML, revealjs, DOCX and
-- PPTX companions so every delivered copy carries the same marking
-- as the PDF. Fires only for non-LaTeX output; the PDF carries the
-- marking in its running header.
--
-- Banner text: "DRAFT – Commercial in Confidence" from the front
-- matter fields `draft` and `confidentiality`.
--
-- Also records the watermark text into the metadata for formats
-- that read it from a document property (DOCX header field).

local banner_formats = { html = true, revealjs = true, docx = true, epub = true }
local plain_formats = { html = true, revealjs = true, docx = true, pptx = true, epub = true }

function Pandoc(doc)
  -- FORMAT is pandoc's writer-format global; PANDOC_WRITER_OPTIONS
  -- is not populated under Quarto.
  if not plain_formats[FORMAT] then
    return doc
  end
  local meta = doc.meta
  local confidentiality = pandoc.utils.stringify(meta['confidentiality'] or meta['classification'] or '')
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

  -- Watermark text for the DOCX header field (read via DOCPROPERTY).
  if FORMAT == 'docx' then
    doc.meta['watermark-text'] = pandoc.MetaString(text)
  end

  if not banner_formats[FORMAT] then
    -- PPTX: the reference-file footer already carries the marking on
    -- every slide; nothing more to inject.
    return doc
  end

  local block
  if FORMAT == 'docx' then
    -- A Div with custom-style maps to a named paragraph style in
    -- the reference document (pandoc docx writer).
    local div = pandoc.Div({ pandoc.Para({ pandoc.Str(text) }) })
    div.attributes['custom-style'] = 'ClassificationBanner'
    block = div
  elseif FORMAT == 'revealjs' then
    -- Revealjs: inject the classification on every slide.
    -- Walk the block list and insert the banner before each slide
    -- (## heading = slide boundary). Also insert at the very start
    -- so the first slide carries the marking.
    local new_blocks = {}
    local banner_html = '<div class="obsidian-classification"><span class="status">'
      .. text .. '</span></div>'
    local banner_block = pandoc.RawBlock('html', banner_html)
    for _, b in ipairs(doc.blocks) do
      -- Insert banner before each Header at slide level (## = level 2)
      if b.t == 'Header' and b.level == 2 then
        table.insert(new_blocks, banner_block)
      end
      table.insert(new_blocks, b)
    end
    -- Also insert at the very start (before any heading)
    table.insert(new_blocks, 1, banner_block)
    doc.blocks = new_blocks
    return doc
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
