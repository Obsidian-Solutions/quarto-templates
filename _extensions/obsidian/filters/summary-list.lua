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
-- lists used for other purposes can opt out with the container class
-- `obsidian-summary-list="false"`:
--
--   ::: {.obsidian-summary-list false="true"}
--   Term
--   : definition
--   :::

local function opt_out(el)
  if el.attributes and el.attributes["false"] then
    return true
  end
  return false
end

function DefinitionList(el)
  if opt_out(el) then
    return el
  end
  -- A DefinitionList element has no classes field, so wrap it in a
  -- Div that carries the component class.
  return pandoc.Div({el}, pandoc.Attr("", {"obsidian-summary-list"}))
end

return { { DefinitionList = DefinitionList } }
