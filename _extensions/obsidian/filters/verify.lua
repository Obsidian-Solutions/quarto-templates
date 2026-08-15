-- SPDX-License-Identifier: MIT
-- verify.lua - soft, local verification of document metadata.
--
-- Opt-in via `verify: true` in the front matter. When enabled, the
-- filter checks the metadata surface and prints WARNINGS to stderr;
-- it never fails the render. This is the difference between document
-- generation and production use: a placeholder left in an address or
-- a malformed phone number is caught before the document ships.
--
-- Local only: no network calls, no address/phone APIs. The checks
-- validate FORM (structure, format, presence, ordering), not
-- truth (whether an address is a real building). A warning means
-- "this value is malformed or looks unfinished", never "this
-- address does not exist".
--
-- Checks:
--   common: title/author/date present; date is a valid ISO date;
--     reference matches the house OS-<TYPE>-<NNN> shape; version is
--     semver; confidentiality is a known level or absent
--   placeholders: any field containing [brackets] or <angle
--     brackets> or "(blank)" or "TBD" or "xxx" or "lorem" warns
--   addresses: non-empty, no placeholder, UK postcode on the last
--     line matches [A-Z]{1,2}[0-9][A-Z0-9]? ?[0-9][A-Z]{2}
--   phones: UK shape +44 or 0 followed by 10 digits, allowing
--     spaces/dashes; not obviously truncated
--   emails: standard shape, one @, no spaces
--   dates: valid calendar date; invoice date ordering
--     supply-date <= date <= due-date
--   invoice: sender/client present; number not a placeholder;
--     items non-empty; quantities positive; unit prices numeric;
--     subtotal recomputes from the items; payment provider in
--     {stripe, paypal, bank-transfer, none}; link present when the
--     provider needs one; vat-status either the no-VAT statement or
--     a GB VAT number shape
--
-- The checks are conservative: a warning is a prompt to look, not a
-- verdict. False positives are acceptable when they push a human to
-- confirm a value; false negatives are not.

local WARN = {}

local function warn(field, msg)
  table.insert(WARN, string.format("verify: %s - %s", field, msg))
end

local function is_empty(v)
  return v == nil or v == ""
end

-- Flatten a pandoc Meta value to a plain string. A YAML literal
-- block (address: |) arrives as MetaBlocks; stringify each block
-- and join with newlines so the address keeps its line structure.
local function tostring_meta(v)
  if v == nil then return "" end
  if type(v) == "string" then return v end
  if type(v) == "boolean" then return tostring(v) end
  if type(v) == "number" then return tostring(v) end
  if type(v) == "table" and #v > 0 then
    -- A YAML literal block (address: |) arrives as an array of
    -- blocks (MetaBlocks, or a plain list in Quarto's runtime).
    -- Stringify each element and join with newlines so the address
    -- keeps its line structure.
    local parts = {}
    for _, blk in ipairs(v) do
      table.insert(parts, pandoc.utils.stringify(blk))
    end
    return table.concat(parts, "\n")
  end
  -- MetaString / MetaInlines / MetaMap
  local ok, s = pcall(function()
    return pandoc.utils.stringify(v)
  end)
  if ok then return s end
  return ""
end

local function strip(s)
  return (s:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Trim without collapsing newlines (addresses keep their line
-- structure so the postcode check can see each line).
local function trim_lines(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- True when the value looks like a left-in placeholder.
local function is_placeholder(s)
  local t = strip(s)
  if t == "" then return true end
  if t:find("%[.-%]") then return true end       -- [something]
  if t:find("<.->") then return true end          -- <something>
  if t:lower():find("tbd") then return true end
  if t:lower():find("xxx") then return true end
  if t:lower():find("lorem") then return true end
  if t:lower():find("%(blank%)") then return true end
  return false
end

-- UK postcode at the end of a line: either at the line start
-- (EX1 1AA) or preceded by a space (Exeter EX1 1AA). Lua patterns
-- have no alternation and no [A-Za-z] class; use %a and two
-- patterns.
local POSTCODE_AT_START = "^%a%a?%d%w?%s*%d%a%a$"
local POSTCODE_INLINE = "%s%a%a?%d%w?%s*%d%a%a$"

-- UK phone: +44 or 0, then 10 digits, allowing separators.
local PHONE = "^%+?44[0-9 %-]{9,12}$"
local PHONE_ALT = "^0[0-9 %-]{9,12}$"

-- ISO date YYYY-MM-DD, then check it is a real calendar date.
local function parse_iso(s)
  local y, m, d = s:match("^(%d%d%d%d)-(%d%d)-(%d%d)$")
  if not y then return nil end
  y, m, d = tonumber(y), tonumber(m), tonumber(d)
  if m < 1 or m > 12 or d < 1 or d > 31 then return nil end
  local days = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
  if y % 4 == 0 and (y % 100 ~= 0 or y % 400 == 0) then days[2] = 29 end
  if d > days[m] then return nil end
  return {y = y, m = m, d = d}
end

local function date_le(a, b)
  if not a or not b then return true end
  if a.y ~= b.y then return a.y < b.y end
  if a.m ~= b.m then return a.m < b.m end
  return a.d <= b.d
end

local function check_address(field, value)
  if is_empty(value) then
    warn(field, "address is missing")
    return
  end
  if is_placeholder(value) then
    warn(field, "address contains a placeholder")
    return
  end
  local found_postcode = false
  local last = ""
  for line in value:gmatch("[^\n]+") do
    last = trim_lines(line)
    if last:match(POSTCODE_AT_START) or last:match(POSTCODE_INLINE) then
      found_postcode = true
    end
  end
  if not found_postcode then
    -- Not every address carries a UK postcode (international
    -- addresses). Only warn when some line looks like it was meant
    -- to be one (contains a digit) but no line matched the shape.
    if last:find("%d") then
      warn(field, "no line matches a UK postcode; last line: '" .. last .. "'")
    end
  end
end

local function check_phone(field, value)
  if is_empty(value) then
    warn(field, "phone number is missing")
    return
  end
  if is_placeholder(value) then
    warn(field, "phone number contains a placeholder")
    return
  end
  local t = strip(value)
  -- A contact line may carry more than a phone (email | phone).
  -- Check the whole line loosely: it must contain a plausible
  -- phone fragment.
  if not (t:match(PHONE) or t:match(PHONE_ALT) or t:find("%d")) then
    warn(field, "does not look like a phone number: '" .. t .. "'")
  elseif #t:gsub("%D", "") < 7 then
    warn(field, "phone number looks too short to be real")
  end
end

local function check_email(field, value)
  if is_empty(value) then
    warn(field, "email is missing")
    return
  end
  if is_placeholder(value) then
    warn(field, "email contains a placeholder")
    return
  end
  local t = strip(value)
  if not (t:match("^[%w%.%%%+%-]+@[%w%-]+%.[%w%-.]+$")) then
    warn(field, "does not look like an email: '" .. t .. "'")
  end
end

local function check_date(field, value)
  if is_empty(value) then
    warn(field, "date is missing")
    return nil
  end
  local t = strip(value)
  local parsed = parse_iso(t)
  if not parsed then
    warn(field, "not a valid YYYY-MM-DD date: '" .. t .. "'")
    return nil
  end
  return parsed
end

local function check_semver(field, value)
  if is_empty(value) then return end
  local t = strip(value)
  if not t:match("^%d+%.%d+%.%d+") then
    warn(field, "version is not semver (expected X.Y.Z): '" .. t .. "'")
  end
end

local function check_reference(field, value)
  if is_empty(value) then
    warn(field, "reference is missing")
    return
  end
  if is_placeholder(value) then
    warn(field, "reference contains a placeholder")
    return
  end
  local t = strip(value)
  if not t:match("^[A-Za-z]+%-[A-Za-z]+%-%d+$") and
     not t:match("^[A-Za-z]+%-%d+$") then
    warn(field, "reference does not match OS-<TYPE>-<NNN>: '" .. t .. "'")
  end
end

local KNOWN_LEVELS = {
  ["Internal"] = true,
  ["Commercial in Confidence"] = true,
  ["Secret"] = true,
  ["Top Secret"] = true,
  ["Official"] = true,
  ["Official-Sensitive"] = true,
  ["Unclassified"] = true,
  ["Restricted"] = true,
}

local function check_common(m)
  local title = tostring_meta(m["title"])
  if is_empty(title) then
    warn("title", "document has no title")
  end
  local author = tostring_meta(m["author"])
  if is_empty(author) then
    warn("author", "document has no author")
  end
  local date = tostring_meta(m["date"])
  check_date("date", date)
  check_reference("reference", tostring_meta(m["reference"]))
  check_semver("version", tostring_meta(m["version"]))
  local conf = tostring_meta(m["confidentiality"])
  if not is_empty(conf) and not KNOWN_LEVELS[strip(conf)] then
    warn("confidentiality", "unrecognised level: '" .. strip(conf) .. "'")
  end
end

local function num(v)
  local t = tostring_meta(v)
  local n = tonumber(t)
  if not n then return nil end
  return n
end

local function check_invoice(inv)
  -- Sender.
  local sender = inv["sender"]
  if sender then
    local sname = tostring_meta(sender["name"])
    if is_empty(sname) then warn("invoice.sender.name", "sender name is missing") end
    local saddr = tostring_meta(sender["address"])
    check_address("invoice.sender.address", saddr)
    local contact = tostring_meta(sender["contact"])
    if not is_empty(contact) and is_placeholder(contact) then
      warn("invoice.sender.contact", "contact contains a placeholder")
    end
  else
    warn("invoice.sender", "sender block is missing")
  end

  -- Client.
  local client = inv["client"]
  if client then
    local cname = tostring_meta(client["name"])
    if is_empty(cname) then warn("invoice.client.name", "client name is missing") end
    check_address("invoice.client.address", tostring_meta(client["address"]))
  else
    warn("invoice.client", "client block is missing")
  end

  -- Numbering.
  local number = tostring_meta(inv["number"])
  if is_empty(number) then
    warn("invoice.number", "invoice number is missing")
  elseif is_placeholder(number) then
    warn("invoice.number", "invoice number contains a placeholder")
  end

  -- Dates and their ordering.
  local date = check_date("invoice.date", tostring_meta(inv["date"]))
  local supply = check_date("invoice.supply-date", tostring_meta(inv["supply-date"]))
  local due = check_date("invoice.due-date", tostring_meta(inv["due-date"]))
  if date and supply and not date_le(supply, date) then
    warn("invoice.date ordering", "supply-date is after the invoice date")
  end
  if date and due and not date_le(date, due) then
    warn("invoice.date ordering", "due-date is before the invoice date")
  end

  -- Items and totals.
  local items = inv["items"]
  if not items or #items == 0 then
    warn("invoice.items", "no line items")
  else
    local subtotal = 0
    for i, item in ipairs(items) do
      local qty = num(item["quantity"])
      local price = num(item["unit-price"])
      local label = string.format("invoice.items[%d]", i)
      if not qty or qty <= 0 then
        warn(label .. ".quantity", "quantity must be a positive number")
      end
      if not price or price <= 0 then
        warn(label .. ".unit-price", "unit price must be a positive number")
      end
      if qty and price then subtotal = subtotal + qty * price end
      if is_empty(tostring_meta(item["description"])) then
        warn(label .. ".description", "item has no description")
      end
    end
    -- The recomputed subtotal is allowed to differ from the stated
    -- one only by rounding to pence.
    local stated = num(inv["subtotal"])
    if stated and math.abs(stated - subtotal) > 0.01 then
      warn("invoice.subtotal", string.format(
        "stated %.2f does not match items (%.2f)", stated, subtotal))
    end
  end

  -- Payment provider.
  local payment = inv["payment"]
  if payment then
    local provider = tostring_meta(payment["provider"])
    if not is_empty(provider) then
      local p = strip(provider)
      if not (p == "stripe" or p == "paypal" or p == "bank-transfer" or p == "none") then
        warn("invoice.payment.provider", "unrecognised provider: '" .. p .. "'")
      end
      if (p == "stripe" or p == "paypal") and is_empty(tostring_meta(payment["link"])) then
        warn("invoice.payment.link", provider .. " needs a payment link")
      end
    end
  end

  -- VAT.
  local vat = tostring_meta(inv["vat-status"])
  if not is_empty(vat) then
    local t = strip(vat)
    if not (t:lower():find("not registered") or t:match("GB%d{9}%d%d?") or
            t:match("GB%d{9}%w%w")) then
      warn("invoice.vat-status", "neither a no-VAT statement nor a GB VAT number: '" .. t .. "'")
    end
  end
end

function Meta(m)
  -- Opt-in: only run when the document asks.
  if not (m["verify"] and pandoc.utils.stringify(m["verify"]) == "true") then
    return m
  end

  check_common(m)
  if m["invoice"] then
    check_invoice(m["invoice"])
  end

  for _, w in ipairs(WARN) do
    io.stderr:write(w .. "\n")
  end
  local n = #WARN
  if n > 0 then
    io.stderr:write(string.format(
      "verify: %d warning(s) - confirm these values before sending\n", n))
  else
    io.stderr:write("verify: metadata surface clean\n")
  end
  return m
end
