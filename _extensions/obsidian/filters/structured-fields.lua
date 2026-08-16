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
-- List values are preserved as their raw arrays so meta_list keeps
-- their structure; stringifying a list would glue its items into one
-- line (the recipient-block bug). Scalars are stringified.
local function meta_map(m, key)
  local v = m[key]
  if v == nil or type(v) ~= "table" then return {} end
  local out = {}
  for k, val in pairs(v) do
    if type(k) == "string" and k ~= "t" then
      if type(val) == "table" and val.t == nil then
        out[k] = val
      else
        out[k] = pandoc.utils.stringify(val)
      end
    end
  end
  return out
end

-- Abort the render with a clear error. Quarto's filter runner
-- (share/filters/main.lua) redefines the global error() to print the
-- message and continue, so a plain error() call would let the render
-- ship a document with a blank recipient block or memo header. Print
-- the message and exit non-zero instead; this aborts under both bare
-- pandoc and quarto render.
local function fail_loud(msg)
  io.stderr:write(msg .. "\n")
  os.exit(1)
end

local function require_field(value, label)
  if value == nil or value == "" then
    fail_loud("structured-fields: missing required field '" .. label .. "'")
  end
end

local function require_list(items, label)
  if items == nil or #items == 0 then
    fail_loud("structured-fields: missing required field '" .. label .. "'")
  end
end

local function para(text)
  return pandoc.Para({ pandoc.Str(text) })
end

-- Front-matter multiline fields (the letter signature) arrive as a
-- YAML block scalar. Pandoc parses that into a paragraph whose newlines
-- are soft breaks; stringify collapses the soft breaks to spaces, so a
-- naive read glues the signature into one line. Rebuild the value as
-- Paras, turning each soft break into a hard line break, whichever
-- shape the metadata arrives in (pandoc userdata or Quarto's plain
-- Lua tables). Returns a list of Paras, or nil when empty.
local function para_field(value)
  if type(value) == "string" then
    if value == "" then return nil end
    return { para_lines(value) }
  end
  if type(value) ~= "table" then return nil end
  local out = {}
  for _, blk in ipairs(value) do
    local content = blk and blk.content
    if type(content) == "table" and #content > 0 then
      local inlines = {}
      for _, inl in ipairs(content) do
        if inl.t == "SoftBreak" then
          table.insert(inlines, pandoc.LineBreak())
        else
          table.insert(inlines, inl)
        end
      end
      table.insert(out, pandoc.Para(inlines))
    end
  end
  if #out == 0 then return nil end
  return out
end

local function bullet(items)
  local blocks = {}
  for _, item in ipairs(items) do
    table.insert(blocks, pandoc.Plain({ pandoc.Str(item) }))
  end
  return pandoc.BulletList(blocks)
end

-- A two-column header table: bold label in the left column, value on
-- the right. Emits a pandoc Table so every output format (PDF, HTML,
-- DOCX, EPUB) typesets it as a bordered header, the classic memo and
-- agenda look. Empty values are dropped so a document never ships a
-- blank row. Built via pandoc.SimpleTable (cells are plain block
-- lists), which pandoc 3.x converts to a real Table; the direct
-- Table/TableHead/TableBody constructors differ across pandoc 3.x
-- minors, so this route keeps the filter portable.
local function label_table(rows)
  local table_rows = {}
  for _, row in ipairs(rows) do
    if row[2] ~= nil and row[2] ~= "" then
      table.insert(table_rows, {
        { pandoc.Str(row[1]) },
        { pandoc.Str(row[2]) },
      })
    end
  end
  if #table_rows == 0 then return nil end
  local st = pandoc.SimpleTable(
    {},
    { pandoc.AlignLeft, pandoc.AlignLeft },
    { 0, 0 },
    { { pandoc.Str("") }, { pandoc.Str("") } },
    table_rows
  )
  return pandoc.utils.from_simple_table(st)
end

-- ---- Letter ----
local function render_letter(m)
  local letter = meta_map(m, "letter")
  local address = meta_list(letter, "address")
  require_list(address, "letter.address")

  local blocks = {}
  -- PDF carries the whole letter head (letterhead, recipient block,
  -- date, reference, subject, opening) in before-body.tex, so the
  -- filter emits nothing for LaTeX. HTML and DOCX get the standard
  -- document header from the reference templates.
  if FORMAT ~= "latex" then
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
  end

  return pandoc.Div(blocks, { class = "obsidian-doc-letter" })
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
  -- Signature: a YAML block scalar, parsed as a Para with soft breaks.
  -- Read the raw value so para_field can turn the soft breaks into
  -- hard line breaks; meta_str would stringify the breaks to spaces.
  local letter_raw = m.letter
  local sig_blocks = letter_raw ~= nil and para_field(letter_raw.signature) or nil
  if sig_blocks ~= nil then
    -- The gap for a handwritten signature (scrlttr2 leaves roughly
    -- six \medskipamount between closing and signature). HTML and
    -- DOCX keep the closing and signature adjacent.
    if FORMAT == "latex" then
      table.insert(blocks, pandoc.RawBlock("latex", "\\vspace{2.5em}"))
    end
    for _, blk in ipairs(sig_blocks) do
      table.insert(blocks, blk)
    end
  end
  -- cc, encl and ps come after the signature block.
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
  return pandoc.Div(blocks, { class = "obsidian-doc-letter-closing" })
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
  -- PDF carries the whole memo head (masthead and colon-line field
  -- block) in before-body.tex, so the filter emits nothing for
  -- LaTeX. HTML and DOCX get the standard document header and the
  -- bordered label table from the reference templates.
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Memo") }))
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-memo" })
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
  -- PDF carries the whole agenda head (masthead and field block) in
  -- before-body.tex, so the filter emits nothing for LaTeX. HTML and
  -- DOCX get the heading and the bordered label table instead. The
  -- attendee, apology and guest lists are body content, so they
  -- render in every format.
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Meeting details") }))
    local tbl = label_table(details)
    if tbl ~= nil then
      table.insert(blocks, tbl)
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
  return pandoc.Div(blocks, { class = "obsidian-doc-agenda" })
end

-- ---- Brief ----
local function render_brief(m)
  local brief = meta_map(m, "brief")
  local key_findings = meta_list(brief, "key-findings")
  local contact = meta_map(brief, "contact")

  local blocks = {}
  -- PDF carries the brief head (series/issue line and key-findings
  -- block) in before-body.tex, so the filter emits nothing for
  -- LaTeX. HTML and DOCX get the standard blocks here. The citation
  -- and contact blocks are body content, so they render in every
  -- format.
  if FORMAT ~= "latex" then
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
  return pandoc.Div(blocks, { class = "obsidian-doc-brief" })
end

-- ---- Decision record ----
local function render_decision(m)
  local decision = meta_map(m, "decision")
  local status = meta_str(decision, "status")
  require_field(status, "decision.status")

  local rows = {
    { "Decision", meta_str(m, "title") or "" },
    { "Status", status },
    { "Date", meta_str(m, "date") or "" },
    { "Reference", meta_str(m, "reference") or "" },
  }
  local makers = meta_list(decision, "decision-makers")
  if #makers > 0 then
    table.insert(rows, { "Decision makers", table.concat(makers, ", ") })
  end
  local consulted = meta_list(decision, "consulted")
  if #consulted > 0 then
    table.insert(rows, { "Consulted", table.concat(consulted, ", ") })
  end
  local informed = meta_list(decision, "informed")
  if #informed > 0 then
    table.insert(rows, { "Informed", table.concat(informed, ", ") })
  end

  local blocks = {}
  -- PDF carries the whole decision head (masthead and colon-line field
  -- block) in before-body.tex, so the filter emits nothing for LaTeX.
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Decision record") }))
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-decision" })
end

-- ---- Meeting minutes ----
local function render_minutes(m)
  local minutes = meta_map(m, "minutes")
  require_field(meta_str(minutes, "committee"), "minutes.committee")
  require_field(meta_str(minutes, "date"), "minutes.date")

  local rows = {
    { "Date", meta_str(minutes, "date") },
    { "Time", meta_str(minutes, "time") or "" },
    { "Location", meta_str(minutes, "location") or "" },
    { "Chair", meta_str(minutes, "chair") or "" },
    { "Notetaker", meta_str(minutes, "notetaker") or "" },
    { "Reference", meta_str(m, "reference") or "" },
  }
  local present = meta_list(minutes, "present")
  local absent = meta_list(minutes, "absent")
  local guests = meta_list(minutes, "guests")

  local blocks = {}
  -- PDF carries the whole minutes head (committee title and colon-line
  -- field block) in before-body.tex, so the filter emits nothing for
  -- LaTeX. The attendance lists are body content, so they render in
  -- every format.
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Meeting details") }))
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  if #present > 0 then
    table.insert(blocks, pandoc.Header(3, { pandoc.Str("Present") }))
    table.insert(blocks, bullet(present))
  end
  if #absent > 0 then
    table.insert(blocks, pandoc.Header(3, { pandoc.Str("Absent") }))
    table.insert(blocks, bullet(absent))
  end
  if #guests > 0 then
    table.insert(blocks, pandoc.Header(3, { pandoc.Str("Guests") }))
    table.insert(blocks, bullet(guests))
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-minutes" })
end

-- ---- Minutes action items (closing marker) ----
-- The action items sort by due date, so an overdue item never sits
-- below a due one. Each action carries owner, due date and text; the
-- sorted list renders in every format.
local function render_minutes_actions(m)
  local minutes = meta_map(m, "minutes")
  local actions = minutes.actions
  local blocks = {}
  if actions ~= nil and type(actions) == "table" then
    local rows = {}
    for _, a in ipairs(actions) do
      local owner = meta_str(a, "owner") or ""
      local due = meta_str(a, "due") or ""
      local text = meta_str(a, "text") or ""
      if text ~= "" or owner ~= "" then
        table.insert(rows, { owner = owner, due = due, text = text })
      end
    end
    table.sort(rows, function(x, y) return (x.due or "") < (y.due or "") end)
    if #rows > 0 then
      table.insert(blocks, pandoc.Header(2, { pandoc.Str("Action items") }))
      local items = {}
      for _, r in ipairs(rows) do
        local parts = {}
        if r.text ~= "" then
          table.insert(parts, pandoc.Str(r.text))
        end
        if r.owner ~= "" then
          table.insert(parts, pandoc.Space())
          table.insert(parts, pandoc.Str("(" .. r.owner))
          if r.due ~= "" then
            table.insert(parts, pandoc.Str("; due " .. r.due))
          end
          table.insert(parts, pandoc.Str(")"))
        elseif r.due ~= "" then
          table.insert(parts, pandoc.Space())
          table.insert(parts, pandoc.Str("(due " .. r.due .. ")"))
        end
        table.insert(items, pandoc.Plain(parts))
      end
      table.insert(blocks, pandoc.BulletList(items))
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-minutes-actions" })
end

-- ---- Contract ----
local function render_contract(m)
  local contract = meta_map(m, "contract")
  local party_a = meta_map(contract, "party-a")
  local party_b = meta_map(contract, "party-b")
  require_field(meta_str(party_a, "name"), "contract.party-a.name")
  require_field(meta_str(party_b, "name"), "contract.party-b.name")

  local blocks = {}
  -- PDF carries the whole contract head (title and party block) in
  -- before-body.tex, so the filter emits nothing for LaTeX.
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Agreement") }))
    local rows = {
      { "Date", meta_str(m, "date") or "" },
      { "Party A", meta_str(party_a, "name") },
      { "Party B", meta_str(party_b, "name") },
      { "Term", meta_str(contract, "term") or "" },
      { "Governing law", meta_str(contract, "governing-law") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
    local addr_a = meta_str(party_a, "address")
    local addr_b = meta_str(party_b, "address")
    if addr_a ~= nil or addr_b ~= nil then
      table.insert(blocks, pandoc.Header(3, { pandoc.Str("Parties") }))
      if addr_a ~= nil and addr_a ~= "" then
        table.insert(blocks, pandoc.Para({ pandoc.Strong(pandoc.Str(meta_str(party_a, "name"))), pandoc.Space(), pandoc.Str(addr_a) }))
      end
      if addr_b ~= nil and addr_b ~= "" then
        table.insert(blocks, pandoc.Para({ pandoc.Strong(pandoc.Str(meta_str(party_b, "name"))), pandoc.Space(), pandoc.Str(addr_b) }))
      end
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-contract" })
end

-- ---- Press release ----
local function render_press_release(m)
  local press = meta_map(m, "press-release")
  local blocks = {}
  -- PDF carries the whole press head (release line, headline,
  -- subheadline, dateline) in before-body.tex, so the filter emits
  -- nothing for LaTeX. The contact block is body content and renders
  -- in every format.
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Press release") }))
    local rows = {
      { "Release", meta_str(press, "status") or "FOR IMMEDIATE RELEASE" },
      { "Headline", meta_str(m, "title") or "" },
      { "Subheadline", meta_str(press, "subheadline") or "" },
      { "Dateline", meta_str(press, "dateline") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  local contacts = meta_list(press, "contacts")
  if #contacts > 0 then
    table.insert(blocks, pandoc.Header(3, { pandoc.Str("Contact") }))
    table.insert(blocks, bullet(contacts))
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-press-release" })
end

-- ---- Newsletter ----
local function render_newsletter(m)
  local newsletter = meta_map(m, "newsletter")
  require_field(meta_str(newsletter, "name"), "newsletter.name")
  require_field(meta_str(newsletter, "issue"), "newsletter.issue")

  local blocks = {}
  -- PDF carries the newsletter masthead in before-body.tex; the
  -- filter emits nothing for LaTeX.
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Newsletter") }))
    local rows = {
      { "Publication", meta_str(newsletter, "name") },
      { "Issue", meta_str(newsletter, "issue") },
      { "Date", meta_str(newsletter, "date") or meta_str(m, "date") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-newsletter" })
end

-- ---- Certificate ----
local function render_certificate(m)
  local certificate = meta_map(m, "certificate")
  require_field(meta_str(certificate, "type"), "certificate.type")
  require_field(meta_str(certificate, "recipient"), "certificate.recipient")

  local blocks = {}
  -- PDF carries the certificate head in before-body.tex; the filter
  -- emits nothing for LaTeX.
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Certificate") }))
    local rows = {
      { "Issuer", meta_str(m, "author") or "" },
      { "Type", meta_str(certificate, "type") },
      { "Recipient", meta_str(certificate, "recipient") },
      { "Date", meta_str(certificate, "date") or meta_str(m, "date") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-certificate" })
end

-- ---- Reading list ----
local function render_reading_list(m)
  local reading_list = meta_map(m, "reading-list")

  local blocks = {}
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Reading list") }))
    local scope = meta_str(reading_list, "scope")
    if scope ~= nil and scope ~= "" then
      table.insert(blocks, pandoc.Para({
        pandoc.Strong(pandoc.Str("Scope:")), pandoc.Space(), pandoc.Str(scope),
      }))
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-reading-list" })
end

-- ---- SOP ----
local function render_sop(m)
  local sop = meta_map(m, "sop")
  require_field(meta_str(sop, "number"), "sop.number")

  local blocks = {}
  -- PDF carries the SOP head in before-body.tex; the filter emits
  -- nothing for LaTeX.
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Standard operating procedure") }))
    local rows = {
      { "SOP number", meta_str(sop, "number") },
      { "Title", meta_str(m, "title") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Approved by", meta_str(sop, "approved-by") or "" },
      { "Revision date", meta_str(sop, "revision-date") or "" },
      { "Author", meta_str(sop, "author") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-sop" })
end

-- ---- After-action report ----
local function render_after_action(m)
  local after_action = meta_map(m, "after-action")

  local blocks = {}
  -- PDF carries the after-action head in before-body.tex; the filter
  -- emits nothing for LaTeX.
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("After-action report") }))
    local rows = {
      { "Event", meta_str(m, "title") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Facilitator", meta_str(after_action, "facilitator") or "" },
      { "Scenario", meta_str(after_action, "scenario") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-after-action" })
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
  ["obsidian-decision"] = render_decision,
  ["obsidian-minutes"] = render_minutes,
  ["obsidian-minutes-actions"] = render_minutes_actions,
  ["obsidian-contract"] = render_contract,
  ["obsidian-press-release"] = render_press_release,
  ["obsidian-newsletter"] = render_newsletter,
  ["obsidian-certificate"] = render_certificate,
  ["obsidian-reading-list"] = render_reading_list,
  ["obsidian-sop"] = render_sop,
  ["obsidian-after-action"] = render_after_action,
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
          table.insert(out, renderer(_G.meta))
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
