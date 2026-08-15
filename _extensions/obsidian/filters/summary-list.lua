-- SPDX-License-Identifier: MIT
-- summary-list.lua
-- Map definition lists to the obsidian summary-list component.
--
-- A markdown definition list:
--
--   Reference
--   : OS-DOC-001
--
-- renders as a key/value table (dt bold left column, dd right) in
-- the HTML companion, matching the metadata box pattern. Definition
-- lists used for other purposes opt out with a marker attribute on
-- the container, so the filter knows the definition list is not a
-- metadata table:
--
--   ::: {.obsidian-summary-list false="true"}
--   Term
--   : definition
--   :::

-- Pandoc runs the DefinitionList filter before the enclosing Div for
-- this element shape, so a per-element flag cannot see the marker in
-- time. Instead the whole document is walked top-down: a Div that
-- carries the opt-out marker suppresses wrapping for its subtree,
-- and every other DefinitionList is wrapped in the component Div.
-- The walk only descends into elements that carry `.content` (block
-- containers, list items, table cells); leaf elements are kept as
-- they are. The function is local so it does not shadow Quarto's
-- own `_utils.walk`.
local function walk_blocks(items, suppressed)
  local out = {}
  for _, item in ipairs(items) do
    if item.t == "Div" then
      local attrs = item.attributes or {}
      local child_suppressed = suppressed
      if attrs["false"] == "true" then
        child_suppressed = true
      end
      item.content = walk_blocks(item.content, child_suppressed)
      out[#out + 1] = item
    elseif item.t == "DefinitionList" then
      if suppressed then
        out[#out + 1] = item
      else
        out[#out + 1] = pandoc.Div({item},
                                   pandoc.Attr("", {"obsidian-summary-list"}))
      end
    elseif item.content ~= nil then
      item.content = walk_blocks(item.content, suppressed)
      out[#out + 1] = item
    else
      out[#out + 1] = item
    end
  end
  return out
end

function Pandoc(doc)
  doc.blocks = walk_blocks(doc.blocks, false)
  return doc
end

return { { Pandoc = Pandoc } }
