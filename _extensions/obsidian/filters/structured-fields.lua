-- SPDX-License-Identifier: MIT
-- structured-fields.lua
-- Renders the structured letter, memo, agenda and brief fields into
-- the body at a marker Div, and errors when a required field is
-- missing.
--
-- The front matter carries the structured fields as nested blocks:
--
--   letter:
--     address: [Recipient Name, Street, Town, Postcode]
--     subject: "Letter subject"
--     opening: "Dear Recipient,"
--     closing: "Yours sincerely,"
--     cc: [Name]
--     encl: [File]
--     ps: "Postscript"
--     signature: "Your Name, Job Title"
--
--   memo:
--     to: [Recipient]
--     from: "Sender"
--     subject: "Memo subject"
--     cosig: "Co-signer"
--     cosig-title: "Co-signer title"
--
--   agenda:
--     meeting: "Meeting Name"
--     date: "2026-08-14"
--     time: "10:00"
--     location: "Room 1"
--     chair: "Chair Name"
--     members: [Name]
--     apologies: [Name]
--     guests: [Name]
--
--   brief:
--     series: "Series Name"
--     issue: "01"
--     key-findings: [Finding]
--     cite-as: "Citation"
--     contact:
--       name: "Contact Name"
--       email: "email@example.com"
--       phone: "01234 567890"
--
-- A document opts in by placing a marker Div in the body:
--
--   ::: {.obsidian-letter}
--   :::
--
-- The filter replaces the marker with the rendered block. Missing
-- required fields stop the render with a clear error, so a document
-- never ships with an empty recipient block or a blank memo header.
--
-- Metadata shape: under Quarto's emulated filter the meta values are
-- plain Lua tables (no .t field on the map itself), while under a
-- bare pandoc run they are MetaMap/MetaList objects. The helpers
-- handle both shapes, so the filter behaves the same in Quarto and
-- in the unit tests.

local function meta_str(m, key)
  local v = m[key]
  if v == nil then return nil end
  return pandoc.utils.stringify(v)
end

-- A list field: MetaList, a plain Lua array, or a single value.
-- Returns an array of strings; an absent field returns {}.
local function meta_list(m, key)
  local v = m[key]
  if v == nil then return {} end
  local out = {}
  local n = 0
  if type(v) == "table" then
    for _, item in ipairs(v) do
      table.insert(out, pandoc.utils.stringify(item))
      n = n + 1
    end
  end
  if n > 0 then return out end
  return { pandoc.utils.stringify(v) }
end

-- A map field: MetaMap or a plain Lua table. Returns {string: string}.
local function meta_map(m, key)
  local v = m[key]
  if v == nil or type(v) ~= "table" then return {} end
  local out = {}
  for k, val in pairs(v) do
    if type(k) == "string" and k ~= "t" then
      out[k] = pandoc.utils.stringify(val)
    end
  end
  return out
end

local function require_field(value, label)
  if value == nil or value == "" then
    error("structured-fields: missing required field '" .. label .. "'")
  end
end

local function require_list(items, label)
  if items == nil or #items == 0 then
    error("structured-fields: missing required field '" .. label .. "'")
  end
end

local function para(text)
  return pandoc.Para({ pandoc.Str(text) })
end

local function bullet(items)
  local blocks = {}
  for _, item in ipairs(items) do
    table.insert(blocks, pandoc.Plain({ pandoc.Str(item) }))
  end
  return pandoc.BulletList(blocks)
end

-- ---- Letter ----
local function render_letter(m)
  local letter = meta_map(m, "letter")
  local address = meta_list(letter, "address")
  require_list(address, "letter.address")

  local blocks = {}
  -- Recipient address
  table.insert(blocks, pandoc.Header(2, { pandoc.Str("Recipient") }))
  for _, line in ipairs(address) do
    table.insert(blocks, para(line))
  end
  -- Reference and subject
  table.insert(blocks, pandoc.Para({
    pandoc.Str("Our reference:"), pandoc.Space(),
    pandoc.Strong(pandoc.Str(meta_str(m, "reference") or "")),
  }))
  local subject = meta_str(letter, "subject")
  if subject ~= nil and subject ~= "" then
    table.insert(blocks, pandoc.Para({
      pandoc.Str("Subject:"), pandoc.Space(),
      pandoc.Strong(pandoc.Str(subject)),
    }))
  end
  -- Opening
  local opening = meta_str(letter, "opening")
  if opening ~= nil and opening ~= "" then
    table.insert(blocks, para(opening))
  end

  return blocks
end

-- The closing half of the letter: closing salutation, cc, encl, ps,
-- signature.
local function render_letter_closing(m)
  local letter = meta_map(m, "letter")
  local blocks = {}
  local closing = meta_str(letter, "closing")
  if closing ~= nil and closing ~= "" then
    table.insert(blocks, para(closing))
  end
  local cc = meta_list(letter, "cc")
  if #cc > 0 then
    table.insert(blocks, pandoc.Para({ pandoc.Str("cc:"), pandoc.Space() }))
    for _, name in ipairs(cc) do
      table.insert(blocks, para(name))
    end
  end
  local encl = meta_list(letter, "encl")
  if #encl > 0 then
    table.insert(blocks, pandoc.Para({ pandoc.Str("Enclosures:"), pandoc.Space() }))
    for _, name in ipairs(encl) do
      table.insert(blocks, para(name))
    end
  end
  local ps = meta_str(letter, "ps")
  if ps ~= nil and ps ~= "" then
    table.insert(blocks, pandoc.Para({ pandoc.Str("P.S."), pandoc.Space(), pandoc.Str(ps) }))
  end
  local signature = meta_str(letter, "signature")
  if signature ~= nil and signature ~= "" then
    table.insert(blocks, para(signature))
  end
  return blocks
end

-- ---- Memo ----
local function render_memo(m)
  local memo = meta_map(m, "memo")
  local to = meta_list(memo, "to")
  require_list(to, "memo.to")
  require_field(meta_str(memo, "from"), "memo.from")
  require_field(meta_str(memo, "subject"), "memo.subject")

  local rows = {
    { "To", table.concat(to, ", ") },
    { "From", meta_str(memo, "from") },
    { "Date", meta_str(m, "date") or "" },
    { "Subject", meta_str(memo, "subject") },
    { "Reference", meta_str(m, "reference") or "" },
  }
  local cosig = meta_str(memo, "cosig")
  if cosig ~= nil and cosig ~= "" then
    table.insert(rows, { "Co-signature", cosig })
  end

  local blocks = {}
  table.insert(blocks, pandoc.Header(2, { pandoc.Str("Memo") }))
  for _, row in ipairs(rows) do
    table.insert(blocks, pandoc.Para({
      pandoc.Strong(pandoc.Str(row[1] .. ":")), pandoc.Space(), pandoc.Str(row[2]),
    }))
  end
  return blocks
end

-- ---- Agenda ----
local function render_agenda(m)
  local agenda = meta_map(m, "agenda")
  require_field(meta_str(agenda, "meeting"), "agenda.meeting")
  require_field(meta_str(agenda, "date"), "agenda.date")
  require_field(meta_str(agenda, "time"), "agenda.time")
  require_field(meta_str(agenda, "location"), "agenda.location")

  local details = {
    { "Meeting", meta_str(agenda, "meeting") },
    { "Date", meta_str(agenda, "date") },
    { "Time", meta_str(agenda, "time") },
    { "Location", meta_str(agenda, "location") },
    { "Chair", meta_str(agenda, "chair") or "" },
  }
  local members = meta_list(agenda, "members")
  local apologies = meta_list(agenda, "apologies")
  local guests = meta_list(agenda, "guests")

  local blocks = {}
  table.insert(blocks, pandoc.Header(2, { pandoc.Str("Meeting details") }))
  for _, row in ipairs(details) do
    if row[2] ~= "" then
      table.insert(blocks, pandoc.Para({
        pandoc.Strong(pandoc.Str(row[1] .. ":")), pandoc.Space(), pandoc.Str(row[2]),
      }))
    end
  end
  if #members > 0 then
    table.insert(blocks, pandoc.Header(3, { pandoc.Str("Attendees") }))
    table.insert(blocks, bullet(members))
  end
  if #apologies > 0 then
    table.insert(blocks, pandoc.Header(3, { pandoc.Str("Apologies") }))
    table.insert(blocks, bullet(apologies))
  end
  if #guests > 0 then
    table.insert(blocks, pandoc.Header(3, { pandoc.Str("Guests") }))
    table.insert(blocks, bullet(guests))
  end
  return blocks
end

-- ---- Brief ----
local function render_brief(m)
  local brief = meta_map(m, "brief")
  local key_findings = meta_list(brief, "key-findings")
  local contact = meta_map(brief, "contact")

  local blocks = {}
  local series = meta_str(brief, "series")
  local issue = meta_str(brief, "issue")
  if series ~= nil and series ~= "" then
    table.insert(blocks, pandoc.Para({
      pandoc.Strong(pandoc.Str("Series:")), pandoc.Space(),
      pandoc.Str(series .. (issue ~= nil and issue ~= "" and (" (" .. issue .. ")") or "")),
    }))
  end
  if #key_findings > 0 then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Key findings") }))
    table.insert(blocks, bullet(key_findings))
  end
  local cite_as = meta_str(brief, "cite-as")
  if cite_as ~= nil and cite_as ~= "" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("How to cite") }))
    table.insert(blocks, para(cite_as))
  end
  local contact_name = meta_str(contact, "name")
  local contact_email = meta_str(contact, "email")
  local contact_phone = meta_str(contact, "phone")
  if contact_name ~= nil or contact_email ~= nil or contact_phone ~= nil then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Contact") }))
    if contact_name ~= nil and contact_name ~= "" then
      table.insert(blocks, para(contact_name))
    end
    if contact_email ~= nil and contact_email ~= "" then
      table.insert(blocks, pandoc.Para({ pandoc.Link(pandoc.Str(contact_email), "mailto:" .. contact_email) }))
    end
    if contact_phone ~= nil and contact_phone ~= "" then
      table.insert(blocks, para(contact_phone))
    end
  end
  return blocks
end

-- ---- Document walk ----
-- The marker Divs carry the class. Replace each with the rendered
-- block. The letter marker splits into two parts: the opening block
-- at the marker, and the closing block is rendered by the Div
-- carrying the .obsidian-letter-closing class at the end of the body.

local renderers = {
  ["obsidian-letter"] = render_letter,
  ["obsidian-letter-closing"] = render_letter_closing,
  ["obsidian-memo"] = render_memo,
  ["obsidian-agenda"] = render_agenda,
  ["obsidian-brief"] = render_brief,
}

local function has_class(el, wanted)
  if el.classes == nil then return false end
  for _, c in ipairs(el.classes) do
    if c == wanted then return true end
  end
  return false
end

local function walk_blocks(blocks, is_top)
  local out = {}
  for _, block in ipairs(blocks) do
    local rendered = false
    if block.t == "Div" then
      for cls, renderer in pairs(renderers) do
        if has_class(block, cls) then
          for _, b in ipairs(renderer(_G.meta)) do
            table.insert(out, b)
          end
          rendered = true
          break
        end
      end
    end
    if not rendered then
      if block.content ~= nil then
        block.content = walk_blocks(block.content, false)
      end
      table.insert(out, block)
    end
  end
  return out
end

return {
  {
    Meta = function(meta)
      _G.meta = meta
      return meta
    end,
    Pandoc = function(doc)
      doc.blocks = walk_blocks(doc.blocks, true)
      return doc
    end,
  },
}
