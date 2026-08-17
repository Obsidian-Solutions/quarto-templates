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

-- ---- Business case ----
local function render_business_case(m)
  local bc = meta_map(m, "business-case")

  local blocks = {}
  -- The PDF header block lives in before-body.tex; the filter emits
  -- nothing for LaTeX.
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Business case") }))
    local rows = {
      { "Title", meta_str(m, "title") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Status", meta_str(bc, "status") or "" },
      { "Version", meta_str(bc, "version") or "" },
      { "Sponsor", meta_str(bc, "sponsor") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-business-case" })
end

-- ---- Project charter ----
local function render_project_charter(m)
  local chart = meta_map(m, "project-charter")

  local blocks = {}
  -- The PDF header block lives in before-body.tex; the filter emits
  -- nothing for LaTeX.
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Project charter") }))
    local rows = {
      { "Project", meta_str(m, "title") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Sponsor", meta_str(chart, "sponsor") or "" },
      { "Team", meta_str(chart, "team") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-project-charter" })
end

-- ---- DPIA ----
local function render_dpia(m)
  local dpia = meta_map(m, "dpia")

  local blocks = {}
  -- The PDF header block lives in before-body.tex; the filter emits
  -- nothing for LaTeX.
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Data protection impact assessment") }))
    local rows = {
      { "Activity", meta_str(dpia, "activity") or "" },
      { "Controller", meta_str(dpia, "controller") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "DPO", meta_str(dpia, "dpo") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-dpia" })
end

-- ---- Audit report ----
local function render_audit_report(m)
  local audit = meta_map(m, "audit-report")
  require_field(meta_str(audit, "number"), "audit-report.number")

  local blocks = {}
  -- The PDF header block lives in before-body.tex; the filter emits
  -- nothing for LaTeX.
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Audit report") }))
    local rows = {
      { "Audit number", meta_str(audit, "number") },
      { "Date", meta_str(m, "date") or "" },
      { "Status", meta_str(audit, "status") or "" },
      { "Scope", meta_str(audit, "scope") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-audit-report" })
end

-- ---- Incident report ----
local function render_incident_report(m)
  local incident = meta_map(m, "incident-report")

  local blocks = {}
  -- The PDF header block lives in before-body.tex; the filter emits
  -- nothing for LaTeX.
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Incident report") }))
    local rows = {
      { "Incident", meta_str(m, "title") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Severity", meta_str(incident, "severity") or "" },
      { "Duration", meta_str(incident, "duration") or "" },
      { "Status", meta_str(incident, "status") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-incident-report" })
end

-- ---- Statement of work ----
local function render_sow(m)
  local sow = meta_map(m, "sow")

  local blocks = {}
  -- The PDF header block lives in before-body.tex; the filter emits
  -- nothing for LaTeX.
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Statement of work") }))
    local rows = {
      { "Project", meta_str(m, "title") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Client", meta_str(sow, "client") or "" },
      { "Period", meta_str(sow, "period") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-sow" })
end

-- ---- Fact sheet ----
local function render_fact_sheet(m)
  local sheet = meta_map(m, "fact-sheet")

  local blocks = {}
  -- The PDF header block lives in before-body.tex; the filter emits
  -- nothing for LaTeX.
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Fact sheet") }))
    local rows = {
      { "Name", meta_str(m, "title") or "" },
      { "Last updated", meta_str(sheet, "last-updated") or "" },
      { "Developer", meta_str(sheet, "developer") or "" },
      { "Launch date", meta_str(sheet, "launch-date") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-fact-sheet" })
end

-- ---- Requirements specification ----
local function render_requirements_spec(m)
  local spec = meta_map(m, "requirements-spec")

  local blocks = {}
  -- The PDF header block lives in before-body.tex; the filter emits
  -- nothing for LaTeX.
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Requirements specification") }))
    local rows = {
      { "Title", meta_str(m, "title") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Version", meta_str(spec, "version") or "" },
      { "Status", meta_str(spec, "status") or "" },
      { "Approval", meta_str(spec, "approval") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-requirements-spec" })
end

-- ---- Technical design document ----
local function render_technical_design(m)
  local design = meta_map(m, "technical-design")

  local blocks = {}
  -- The PDF header block lives in before-body.tex; the filter emits
  -- nothing for LaTeX.
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Technical design document") }))
    local rows = {
      { "Title", meta_str(m, "title") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Version", meta_str(design, "version") or "" },
      { "Status", meta_str(design, "status") or "" },
      { "Author", meta_str(design, "author") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-technical-design" })
end

-- ---- Reference letter ----
local function render_reference_letter(m)
  local ref_letter = meta_map(m, "reference-letter")

  local blocks = {}
  -- The PDF header block lives in before-body.tex; the filter emits
  -- nothing for LaTeX.
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Reference letter") }))
    local rows = {
      { "Date", meta_str(m, "date") or "" },
      { "Addressee", meta_str(ref_letter, "addressee") or "" },
      { "Candidate", meta_str(ref_letter, "candidate") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
    local salutation = meta_str(ref_letter, "salutation")
    if salutation ~= nil and salutation ~= "" then
      table.insert(blocks, para(salutation))
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-reference-letter" })
end

-- ---- Staff report ----
local function render_staff_report(m)
  local staff = meta_map(m, "staff-report")
  require_field(meta_str(staff, "to"), "staff-report.to")
  require_field(meta_str(staff, "from"), "staff-report.from")

  local blocks = {}
  -- The PDF header block lives in before-body.tex; the filter emits
  -- nothing for LaTeX.
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Staff report") }))
    local rows = {
      { "To", meta_str(staff, "to") },
      { "From", meta_str(staff, "from") },
      { "Date", meta_str(m, "date") or "" },
      { "Subject", meta_str(m, "title") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-staff-report" })
end

-- ---- Release notes ----
local function render_release_notes(m)
  local notes = meta_map(m, "release-notes")
  require_field(meta_str(notes, "version"), "release-notes.version")

  local blocks = {}
  -- The PDF header block lives in before-body.tex; the filter emits
  -- nothing for LaTeX.
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Release notes") }))
    local rows = {
      { "Product", meta_str(m, "title") or "" },
      { "Version", meta_str(notes, "version") },
      { "Date", meta_str(m, "date") or "" },
      { "Status", meta_str(notes, "status") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-release-notes" })
end

-- ---- Test report ----
local function render_test_report(m)
  local report = meta_map(m, "test-report")

  local blocks = {}
  -- The PDF header block lives in before-body.tex; the filter emits
  -- nothing for LaTeX.
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Test report") }))
    local rows = {
      { "Project", meta_str(m, "title") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Version", meta_str(report, "version") or "" },
      { "Tester", meta_str(report, "tester") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-test-report" })
end

-- ---- Request for proposal ----
local function render_rfp(m)
  local rfp = meta_map(m, "rfp")
  require_field(meta_str(rfp, "issuer"), "rfp.issuer")

  local blocks = {}
  -- The PDF header block lives in before-body.tex; the filter emits
  -- nothing for LaTeX.
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Request for proposal") }))
    local rows = {
      { "Title", meta_str(m, "title") or "" },
      { "Issuer", meta_str(rfp, "issuer") },
      { "Date", meta_str(m, "date") or "" },
      { "Deadline", meta_str(rfp, "deadline") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-rfp" })
end

-- ---- Service level agreement ----
local function render_sla(m)
  local sla = meta_map(m, "sla")
  require_field(meta_str(sla, "parties"), "sla.parties")

  local blocks = {}
  -- The PDF header block lives in before-body.tex; the filter emits
  -- nothing for LaTeX.
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Service level agreement") }))
    local rows = {
      { "Service", meta_str(m, "title") or "" },
      { "Parties", meta_str(sla, "parties") },
      { "Date", meta_str(m, "date") or "" },
      { "Term", meta_str(sla, "term") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-sla" })
end

-- ---- Exam paper ----
local function render_exam_paper(m)
  local exam = meta_map(m, "exam-paper")

  local blocks = {}
  -- The PDF header block lives in before-body.tex; the filter emits
  -- nothing for LaTeX.
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Exam paper") }))
    local rows = {
      { "Course", meta_str(exam, "course") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Duration", meta_str(exam, "duration") or "" },
      { "Examiner", meta_str(exam, "examiner") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-exam-paper" })
end

-- ---- Laboratory report ----
local function render_lab_report(m)
  local lab = meta_map(m, "lab-report")

  local blocks = {}
  -- The PDF header block lives in before-body.tex; the filter emits
  -- nothing for LaTeX.
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Laboratory report") }))
    local rows = {
      { "Experiment", meta_str(m, "title") or "" },
      { "Course", meta_str(lab, "course") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Student", meta_str(lab, "student") or "" },
      { "Partner", meta_str(lab, "partner") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-lab-report" })
end

-- ---- Syllabus ----
local function render_syllabus(m)
  local syl = meta_map(m, "syllabus")

  local blocks = {}
  -- The PDF header block lives in before-body.tex; the filter emits
  -- nothing for LaTeX.
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Syllabus") }))
    local rows = {
      { "Course", meta_str(m, "title") or "" },
      { "Code", meta_str(syl, "code") or "" },
      { "Term", meta_str(syl, "term") or "" },
      { "Instructor", meta_str(syl, "instructor") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-syllabus" })
end

-- ---- Essay ----
local function render_essay(m)
  local essay = meta_map(m, "essay")

  local blocks = {}
  -- The PDF header block lives in before-body.tex; the filter emits
  -- nothing for LaTeX.
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Essay") }))
    local rows = {
      { "Title", meta_str(m, "title") or "" },
      { "Course", meta_str(essay, "course") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Word count", meta_str(essay, "word-count") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-essay" })
end

-- ---- Research proposal ----
local function render_research_proposal(m)
  local rp = meta_map(m, "research-proposal")

  local blocks = {}
  -- The PDF header block lives in before-body.tex; the filter emits
  -- nothing for LaTeX.
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Research proposal") }))
    local rows = {
      { "Proposal", meta_str(m, "title") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Supervisor", meta_str(rp, "supervisor") or "" },
      { "Duration", meta_str(rp, "duration") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-research-proposal" })
end

-- ---- Dissertation proposal ----
local function render_dissertation_proposal(m)
  local dp = meta_map(m, "dissertation-proposal")

  local blocks = {}
  -- The PDF header block lives in before-body.tex; the filter emits
  -- nothing for LaTeX.
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Dissertation proposal") }))
    local rows = {
      { "Dissertation", meta_str(m, "title") or "" },
      { "Degree", meta_str(dp, "degree") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Supervisor", meta_str(dp, "supervisor") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-dissertation-proposal" })
end

-- ---- Literature review ----
local function render_literature_review(m)
  local lr = meta_map(m, "literature-review")

  local blocks = {}
  -- The PDF header block lives in before-body.tex; the filter emits
  -- nothing for LaTeX.
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Literature review") }))
    local rows = {
      { "Topic", meta_str(m, "title") or "" },
      { "Scope", meta_str(lr, "scope") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Reviewer", meta_str(lr, "reviewer") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-literature-review" })
end

-- ---- Marking rubric ----
local function render_marking_rubric(m)
  local rubric = meta_map(m, "marking-rubric")

  local blocks = {}
  -- The PDF header block lives in before-body.tex; the filter emits
  -- nothing for LaTeX.
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Marking rubric") }))
    local rows = {
      { "Assignment", meta_str(m, "title") or "" },
      { "Course", meta_str(rubric, "course") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Marker", meta_str(rubric, "marker") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-marking-rubric" })
end

-- ---- Lecture notes ----
local function render_lecture_notes(m)
  local notes = meta_map(m, "lecture-notes")

  local blocks = {}
  -- The PDF header block lives in before-body.tex; the filter emits
  -- nothing for LaTeX.
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Lecture notes") }))
    local rows = {
      { "Lecture", meta_str(m, "title") or "" },
      { "Course", meta_str(notes, "course") or "" },
      { "Date", meta_str(notes, "date") or "" },
      { "Speaker", meta_str(notes, "speaker") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-lecture-notes" })
end

-- ---- Legal memo ----
local function render_legal_memo(m)
  local lm = meta_map(m, "legal-memo")
  require_field(meta_str(lm, "to"), "legal-memo.to")

  local blocks = {}
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Legal memo") }))
    local rows = {
      { "To", meta_str(lm, "to") },
      { "From", meta_str(lm, "from") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Re", meta_str(m, "title") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-legal-memo" })
end

-- ---- Board minutes ----
local function render_board_minutes(m)
  local bm = meta_map(m, "board-minutes")

  local blocks = {}
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Board minutes") }))
    local rows = {
      { "Company", meta_str(bm, "company") or "" },
      { "Date", meta_str(bm, "date") or "" },
      { "Location", meta_str(bm, "location") or "" },
      { "Chair", meta_str(bm, "chair") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-board-minutes" })
end

-- ---- Corporate resolution ----
local function render_corporate_resolution(m)
  local cr = meta_map(m, "corporate-resolution")

  local blocks = {}
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Corporate resolution") }))
    local rows = {
      { "Company", meta_str(cr, "company") or "" },
      { "Resolution", meta_str(cr, "number") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-corporate-resolution" })
end

-- ---- Board pack ----
local function render_board_pack(m)
  local bp = meta_map(m, "board-pack")

  local blocks = {}
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Board pack") }))
    local rows = {
      { "Meeting", meta_str(bp, "meeting") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Period", meta_str(bp, "period") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-board-pack" })
end

-- ---- Strategy paper ----
local function render_strategy_paper(m)
  local sp = meta_map(m, "strategy-paper")

  local blocks = {}
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Strategy paper") }))
    local rows = {
      { "Title", meta_str(m, "title") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Version", meta_str(sp, "version") or "" },
      { "Owner", meta_str(sp, "owner") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-strategy-paper" })
end

-- ---- Policy document ----
local function render_policy_document(m)
  local pd = meta_map(m, "policy-document")

  local blocks = {}
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Policy document") }))
    local rows = {
      { "Title", meta_str(m, "title") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Version", meta_str(pd, "version") or "" },
      { "Owner", meta_str(pd, "owner") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-policy-document" })
end

-- ---- Procedure document ----
local function render_procedure_document(m)
  local pd = meta_map(m, "procedure-document")

  local blocks = {}
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Procedure document") }))
    local rows = {
      { "Title", meta_str(m, "title") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Version", meta_str(pd, "version") or "" },
      { "Owner", meta_str(pd, "owner") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-procedure-document" })
end

-- ---- Framework document ----
local function render_framework_document(m)
  local fd = meta_map(m, "framework-document")

  local blocks = {}
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Framework document") }))
    local rows = {
      { "Title", meta_str(m, "title") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Version", meta_str(fd, "version") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-framework-document" })
end

-- ---- Terms and conditions ----
local function render_terms_conditions(m)
  local tc = meta_map(m, "terms-conditions")

  local blocks = {}
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Terms and conditions") }))
    local rows = {
      { "Parties", meta_str(tc, "parties") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Term", meta_str(tc, "term") or "" },
      { "Governing law", meta_str(tc, "governing-law") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-terms-conditions" })
end

-- ---- Data processing agreement ----
local function render_dpa(m)
  local dpa = meta_map(m, "dpa")

  local blocks = {}
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Data processing agreement") }))
    local rows = {
      { "Controller", meta_str(dpa, "controller") or "" },
      { "Processor", meta_str(dpa, "processor") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-dpa" })
end

-- ---- Privacy policy ----
local function render_privacy_policy(m)
  local pp = meta_map(m, "privacy-policy")

  local blocks = {}
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Privacy policy") }))
    local rows = {
      { "Controller", meta_str(pp, "controller") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Jurisdiction", meta_str(pp, "jurisdiction") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-privacy-policy" })
end

-- ---- Non-compete agreement ----
local function render_non_compete(m)
  local nc = meta_map(m, "non-compete")

  local blocks = {}
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Non-compete agreement") }))
    local rows = {
      { "Parties", meta_str(nc, "parties") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Term", meta_str(nc, "term") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-non-compete" })
end

-- ---- Cease and desist ----
local function render_cease_desist(m)
  local cd = meta_map(m, "cease-desist")

  local blocks = {}
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Cease and desist") }))
    local rows = {
      { "Recipient", meta_str(cd, "recipient") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-cease-desist" })
end

-- ---- Offer letter ----
local function render_offer_letter(m)
  local ol = meta_map(m, "offer-letter")
  require_field(meta_str(ol, "employee"), "offer-letter.employee")

  local blocks = {}
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Offer letter") }))
    local rows = {
      { "Employee", meta_str(ol, "employee") },
      { "Position", meta_str(ol, "position") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Start date", meta_str(ol, "start-date") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-offer-letter" })
end

-- ---- Termination letter ----
local function render_termination_letter(m)
  local tl = meta_map(m, "termination-letter")
  require_field(meta_str(tl, "employee"), "termination-letter.employee")

  local blocks = {}
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Termination letter") }))
    local rows = {
      { "Employee", meta_str(tl, "employee") },
      { "Date", meta_str(m, "date") or "" },
      { "Last day", meta_str(tl, "last-day") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-termination-letter" })
end

-- ---- Resignation letter ----
local function render_resignation_letter(m)
  local rl = meta_map(m, "resignation-letter")
  require_field(meta_str(rl, "employee"), "resignation-letter.employee")

  local blocks = {}
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Resignation letter") }))
    local rows = {
      { "Employee", meta_str(rl, "employee") },
      { "Date", meta_str(m, "date") or "" },
      { "Last day", meta_str(rl, "last-day") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-resignation-letter" })
end

-- ---- Warning letter ----
local function render_warning_letter(m)
  local wl = meta_map(m, "warning-letter")
  require_field(meta_str(wl, "employee"), "warning-letter.employee")

  local blocks = {}
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Warning letter") }))
    local rows = {
      { "Employee", meta_str(wl, "employee") },
      { "Subject", meta_str(m, "title") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-warning-letter" })
end

-- ---- Disciplinary notice ----
local function render_disciplinary_notice(m)
  local dn = meta_map(m, "disciplinary-notice")
  require_field(meta_str(dn, "employee"), "disciplinary-notice.employee")

  local blocks = {}
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Disciplinary notice") }))
    local rows = {
      { "Employee", meta_str(dn, "employee") },
      { "Date", meta_str(m, "date") or "" },
      { "Meeting date", meta_str(dn, "meeting-date") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-disciplinary-notice" })
end

-- ---- Job description ----
local function render_job_description(m)
  local jd = meta_map(m, "job-description")

  local blocks = {}
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Job description") }))
    local rows = {
      { "Role", meta_str(m, "title") or "" },
      { "Department", meta_str(jd, "department") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Location", meta_str(jd, "location") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-job-description" })
end

-- ---- Exit interview ----
local function render_exit_interview(m)
  local ei = meta_map(m, "exit-interview")
  require_field(meta_str(ei, "employee"), "exit-interview.employee")

  local blocks = {}
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Exit interview") }))
    local rows = {
      { "Employee", meta_str(ei, "employee") },
      { "Department", meta_str(ei, "department") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Interviewer", meta_str(ei, "interviewer") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-exit-interview" })
end

-- ---- Individual development plan ----
local function render_idp(m)
  local idp = meta_map(m, "idp")
  require_field(meta_str(idp, "employee"), "idp.employee")

  local blocks = {}
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Individual development plan") }))
    local rows = {
      { "Employee", meta_str(idp, "employee") },
      { "Role", meta_str(idp, "role") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Manager", meta_str(idp, "manager") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-idp" })
end

-- ---- Onboarding checklist ----
local function render_onboarding_checklist(m)
  local oc = meta_map(m, "onboarding-checklist")
  require_field(meta_str(oc, "employee"), "onboarding-checklist.employee")

  local blocks = {}
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Onboarding checklist") }))
    local rows = {
      { "Employee", meta_str(oc, "employee") },
      { "Role", meta_str(oc, "role") or "" },
      { "Start date", meta_str(oc, "start-date") or "" },
      { "Manager", meta_str(oc, "manager") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-onboarding-checklist" })
end

-- ---- Timesheet ----
local function render_timesheet(m)
  local ts = meta_map(m, "timesheet")
  require_field(meta_str(ts, "employee"), "timesheet.employee")

  local blocks = {}
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Timesheet") }))
    local rows = {
      { "Employee", meta_str(ts, "employee") },
      { "Period", meta_str(ts, "period") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Manager", meta_str(ts, "manager") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-timesheet" })
end

-- ---- Job safety analysis ----
local function render_jsa(m)
  local jsa = meta_map(m, "jsa")

  local blocks = {}
  -- The PDF header block lives in before-body.tex; the filter emits
  -- nothing for LaTeX.
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Job safety analysis") }))
    local rows = {
      { "Activity", meta_str(m, "title") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Location", meta_str(jsa, "location") or "" },
      { "Analyst", meta_str(jsa, "analyst") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-jsa" })
end

-- ---- Permit to work ----
local function render_permit_to_work(m)
  local ptw = meta_map(m, "permit-to-work")

  local blocks = {}
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Permit to work") }))
    local rows = {
      { "Work", meta_str(m, "title") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Location", meta_str(ptw, "location") or "" },
      { "Validity", meta_str(ptw, "validity") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-permit-to-work" })
end

-- ---- Safety data sheet ----
local function render_sds(m)
  local sds = meta_map(m, "sds")

  local blocks = {}
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Safety data sheet") }))
    local rows = {
      { "Product", meta_str(m, "title") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Version", meta_str(sds, "version") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-sds" })
end

-- ---- Shift handover ----
local function render_shift_handover(m)
  local sh = meta_map(m, "shift-handover")

  local blocks = {}
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Shift handover") }))
    local rows = {
      { "Shift", meta_str(m, "title") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "From", meta_str(sh, "from") or "" },
      { "To", meta_str(sh, "to") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-shift-handover" })
end

-- ---- Daily activity report ----
local function render_daily_activity(m)
  local da = meta_map(m, "daily-activity")

  local blocks = {}
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Daily activity report") }))
    local rows = {
      { "Date", meta_str(m, "date") or "" },
      { "Operator", meta_str(da, "operator") or "" },
      { "Location", meta_str(da, "location") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-daily-activity" })
end

-- ---- Equipment checkout ----
local function render_equipment_checkout(m)
  local ec = meta_map(m, "equipment-checkout")

  local blocks = {}
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Equipment checkout") }))
    local rows = {
      { "Equipment", meta_str(m, "title") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Borrower", meta_str(ec, "borrower") or "" },
      { "Return date", meta_str(ec, "return-date") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-equipment-checkout" })
end

-- ---- Purchase requisition ----
local function render_purchase_requisition(m)
  local pr = meta_map(m, "purchase-requisition")
  require_field(meta_str(pr, "number"), "purchase-requisition.number")

  local blocks = {}
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Purchase requisition") }))
    local rows = {
      { "Requisition", meta_str(pr, "number") },
      { "Department", meta_str(pr, "department") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Requester", meta_str(pr, "requester") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-purchase-requisition" })
end

-- ---- Packing list ----
local function render_packing_list(m)
  local pl = meta_map(m, "packing-list")

  local blocks = {}
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Packing list") }))
    local rows = {
      { "Order", meta_str(pl, "order") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Shipper", meta_str(pl, "shipper") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-packing-list" })
end

-- ---- Shipping manifest ----
local function render_shipping_manifest(m)
  local sm = meta_map(m, "shipping-manifest")

  local blocks = {}
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Shipping manifest") }))
    local rows = {
      { "Manifest", meta_str(sm, "number") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Carrier", meta_str(sm, "carrier") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-shipping-manifest" })
end

-- ---- Purchase order ----
local function render_purchase_order(m)
  local po = meta_map(m, "purchase-order")
  require_field(meta_str(po, "number"), "purchase-order.number")

  local blocks = {}
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Purchase order") }))
    local rows = {
      { "Order", meta_str(po, "number") },
      { "Supplier", meta_str(po, "supplier") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Delivery", meta_str(po, "delivery-date") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-purchase-order" })
end

-- ---- Quote ----
local function render_quote(m)
  local q = meta_map(m, "quote")

  local blocks = {}
  if FORMAT ~= "latex" then
    table.insert(blocks, pandoc.Header(2, { pandoc.Str("Quote") }))
    local rows = {
      { "Quote", meta_str(q, "number") or "" },
      { "Client", meta_str(q, "client") or "" },
      { "Date", meta_str(m, "date") or "" },
      { "Valid until", meta_str(q, "valid-until") or "" },
      { "Reference", meta_str(m, "reference") or "" },
    }
    local tbl = label_table(rows)
    if tbl ~= nil then
      table.insert(blocks, tbl)
    end
  end
  return pandoc.Div(blocks, { class = "obsidian-doc-quote" })
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
  ["obsidian-business-case"] = render_business_case,
  ["obsidian-project-charter"] = render_project_charter,
  ["obsidian-dpia"] = render_dpia,
  ["obsidian-audit-report"] = render_audit_report,
  ["obsidian-incident-report"] = render_incident_report,
  ["obsidian-sow"] = render_sow,
  ["obsidian-fact-sheet"] = render_fact_sheet,
  ["obsidian-requirements-spec"] = render_requirements_spec,
  ["obsidian-technical-design"] = render_technical_design,
  ["obsidian-reference-letter"] = render_reference_letter,
  ["obsidian-staff-report"] = render_staff_report,
  ["obsidian-release-notes"] = render_release_notes,
  ["obsidian-test-report"] = render_test_report,
  ["obsidian-rfp"] = render_rfp,
  ["obsidian-sla"] = render_sla,
  ["obsidian-exam-paper"] = render_exam_paper,
  ["obsidian-lab-report"] = render_lab_report,
  ["obsidian-syllabus"] = render_syllabus,
  ["obsidian-essay"] = render_essay,
  ["obsidian-research-proposal"] = render_research_proposal,
  ["obsidian-dissertation-proposal"] = render_dissertation_proposal,
  ["obsidian-literature-review"] = render_literature_review,
  ["obsidian-marking-rubric"] = render_marking_rubric,
  ["obsidian-lecture-notes"] = render_lecture_notes,
  ["obsidian-legal-memo"] = render_legal_memo,
  ["obsidian-board-minutes"] = render_board_minutes,
  ["obsidian-corporate-resolution"] = render_corporate_resolution,
  ["obsidian-board-pack"] = render_board_pack,
  ["obsidian-strategy-paper"] = render_strategy_paper,
  ["obsidian-policy-document"] = render_policy_document,
  ["obsidian-procedure-document"] = render_procedure_document,
  ["obsidian-framework-document"] = render_framework_document,
  ["obsidian-terms-conditions"] = render_terms_conditions,
  ["obsidian-dpa"] = render_dpa,
  ["obsidian-privacy-policy"] = render_privacy_policy,
  ["obsidian-non-compete"] = render_non_compete,
  ["obsidian-cease-desist"] = render_cease_desist,
  ["obsidian-offer-letter"] = render_offer_letter,
  ["obsidian-termination-letter"] = render_termination_letter,
  ["obsidian-resignation-letter"] = render_resignation_letter,
  ["obsidian-warning-letter"] = render_warning_letter,
  ["obsidian-disciplinary-notice"] = render_disciplinary_notice,
  ["obsidian-job-description"] = render_job_description,
  ["obsidian-exit-interview"] = render_exit_interview,
  ["obsidian-idp"] = render_idp,
  ["obsidian-onboarding-checklist"] = render_onboarding_checklist,
  ["obsidian-timesheet"] = render_timesheet,
  ["obsidian-jsa"] = render_jsa,
  ["obsidian-permit-to-work"] = render_permit_to_work,
  ["obsidian-sds"] = render_sds,
  ["obsidian-shift-handover"] = render_shift_handover,
  ["obsidian-daily-activity"] = render_daily_activity,
  ["obsidian-equipment-checkout"] = render_equipment_checkout,
  ["obsidian-purchase-requisition"] = render_purchase_requisition,
  ["obsidian-packing-list"] = render_packing_list,
  ["obsidian-shipping-manifest"] = render_shipping_manifest,
  ["obsidian-purchase-order"] = render_purchase_order,
  ["obsidian-quote"] = render_quote,
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
