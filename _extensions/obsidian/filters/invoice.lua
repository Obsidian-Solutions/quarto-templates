-- SPDX-License-Identifier: MIT
-- invoice.lua
-- Expand the structured `invoice:` metadata block into the document
-- body at a marker Div:
--
--   ::: {.obsidian-invoice}
--   :::
--
-- The filter replaces the marker's content with the generated client
-- block, line-item table, totals, and payment block. Everything else
-- the author writes stays untouched, so notes and sign-off can sit
-- around the invoice data.
--
-- Front matter example:
--
--   invoice:
--     number: "2026-008"
--     date: "2026-08-31"
--     client:
--       name: "Acme Ltd"
--       address: |
--         1 High Street
--         Exeter EX1 1AA
--     items:
--       - description: "Server care retainer, August 2026"
--         quantity: 1
--         unit-price: "300.00"
--     payment:
--       terms: "Due within 14 days"
--       provider: "stripe"
--       link: "https://buy.stripe.com/..."
--
-- The payment block renders differently per provider so the invoice
-- stays provider-agnostic:
--   stripe | paypal | generic: one "Pay now" line with the link
--   bank-transfer: bank details block (bank, sort code, account,
--     account name, payment reference)
--   none (or absent): payment terms only
--
-- Totals are computed in pence (integers) to avoid float drift, then
-- formatted with two decimal places. `discount` and `tax` metadata
-- subtract from the subtotal (a negative value adds). All amounts are
-- pounds sterling (GBP); the author controls the currency symbol in
-- the unit-price strings.
--
-- Metadata values in pandoc are MetaInlines/MetaBlocks/MetaList
-- objects, not AST nodes: they carry no `.t` field. Stringify them
-- with pandoc.utils.stringify and inspect them with
-- pandoc.utils.type.

-- Stringify any metadata value to plain text.
local function tostring_meta(v)
  if v == nil then
    return ""
  end
  return pandoc.utils.stringify(v)
end

-- True when the value is a non-empty metadata list.
local function is_list(v)
  if type(v) ~= "table" then
    return false
  end
  local t = pandoc.utils.type(v)
  if t ~= "MetaList" and t ~= "List" then
    return false
  end
  return #v > 0
end

-- An empty table caption. pandoc.Caption exists in pandoc 3.1.2+
-- (the CI apt pandoc is older and lacks it), so fall back to an empty
-- plain caption object. Tables here never show a caption.
local function empty_caption()
  if pandoc.Caption ~= nil then
    return pandoc.Caption()
  end
  return { pandoc.Str("") }
end

-- Parse a money string to integer pence. Strips anything that is not
-- a digit or a decimal point, so "300.00", "£300.00", and "300" all
-- parse to 30000.
local function parse_pence(v)
  local s = tostring_meta(v):gsub("[^%d.]", "")
  local n = tonumber(s)
  if n == nil then
    return nil
  end
  return math.floor(n * 100 + 0.5)
end

local function format_pence(p)
  local pounds = math.floor(p / 100)
  local pence = p % 100
  return string.format("%d.%02d", pounds, pence)
end

-- Format an ISO date (2026-08-15) as a UK date (15 August 2026).
-- Passes anything unparseable through unchanged, so authors can write
-- either form in the front matter.
local MONTHS = {
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December",
}

local function format_date(v)
  local s = tostring_meta(v)
  local year, month, day = s:match("^(%d%d%d%d)-(%d%d)-(%d%d)$")
  if year == nil then
    return s
  end
  local m = tonumber(month)
  if m == nil or m < 1 or m > 12 then
    return s
  end
  return string.format("%d %s %s", tonumber(day), MONTHS[m], year)
end

-- A label/value paragraph: bold label, colon, value.
local function kv_para(label, value)
  return pandoc.Para({
    pandoc.Strong({ pandoc.Str(label) }),
    pandoc.Str(": " .. value),
  })
end

-- The sender letterhead block at the top of the invoice: business
-- name, address, and contact, mirroring a printed letterhead.
-- The invoice: metadata may carry a `sender:` block; otherwise the
-- document `author` is used.
local function sender_block(inv, doc_meta)
  local blocks = {}
  local sender = inv["sender"] or {}
  local name = sender["name"] ~= nil and tostring_meta(sender["name"]) or tostring_meta(doc_meta["author"])
  if name ~= "" then
    blocks[#blocks + 1] = pandoc.Para({ pandoc.Strong({ pandoc.Str(name) }) })
  end
  local address = sender["address"]
  if address ~= nil then
    for line in (tostring_meta(address) .. "\n"):gmatch("(.-)\n") do
      blocks[#blocks + 1] = pandoc.Para({ pandoc.Str(line) })
    end
  end
  local contact = sender["contact"]
  if contact ~= nil then
    blocks[#blocks + 1] = pandoc.Para({ pandoc.Str(tostring_meta(contact)) })
  end
  return blocks
end

-- The client block: "Bill to" label, name, address lines, then the
-- invoice number, date, and optional due date as a metadata row.
local function client_block(inv)
  local blocks = {}
  local client = inv["client"]
  if client ~= nil then
    blocks[#blocks + 1] = pandoc.Para({
      pandoc.Strong({ pandoc.Str("Bill to") }),
    })
    local name = client["name"]
    if name ~= nil then
      blocks[#blocks + 1] = pandoc.Para({ pandoc.Str(tostring_meta(name)) })
    end
    local address = client["address"]
    if address ~= nil then
      for line in (tostring_meta(address) .. "\n"):gmatch("(.-)\n") do
        blocks[#blocks + 1] = pandoc.Para({ pandoc.Str(line) })
      end
    end
  end
  return blocks
end

-- The invoice reference block: number, purchase order, invoice date,
-- supply date, and optional due date as separate right-aligned lines,
-- so each value sits on its own line in the narrow right column of the
-- header table.
local function reference_block(inv)
  local number = inv["number"]
  local po = inv["po-number"]
  local date = inv["date"]
  local supply_date = inv["supply-date"]
  local due_date = inv["due-date"]
  local blocks = {}
  if number ~= nil then
    blocks[#blocks + 1] = pandoc.Para({
      pandoc.Strong({ pandoc.Str("Invoice number") }),
      pandoc.Str(": " .. tostring_meta(number)),
    })
  end
  if po ~= nil then
    blocks[#blocks + 1] = pandoc.Para({
      pandoc.Strong({ pandoc.Str("Purchase order") }),
      pandoc.Str(": " .. tostring_meta(po)),
    })
  end
  if date ~= nil then
    blocks[#blocks + 1] = pandoc.Para({
      pandoc.Strong({ pandoc.Str("Invoice date") }),
      pandoc.Str(": " .. format_date(date)),
    })
  end
  if supply_date ~= nil then
    blocks[#blocks + 1] = pandoc.Para({
      pandoc.Strong({ pandoc.Str("Supply date") }),
      pandoc.Str(": " .. format_date(supply_date)),
    })
  end
  if due_date ~= nil then
    blocks[#blocks + 1] = pandoc.Para({
      pandoc.Strong({ pandoc.Str("Due date") }),
      pandoc.Str(": " .. format_date(due_date)),
    })
  end
  return blocks
end

-- The header table: Bill to on the left, reference row on the right,
-- like a commercial invoice letterhead.
local function header_table(inv)
  local left = client_block(inv)
  local right = reference_block(inv)
  if #left == 0 and #right == 0 then
    return {}
  end
  local colspecs = {
    { pandoc.AlignLeft, 0.55 },
    { pandoc.AlignRight, 0.45 },
  }
  local head = pandoc.TableHead{}
  local bodies = {
    {
      attr = {},
      body = {
        pandoc.Row{
          pandoc.Cell(pandoc.Blocks(left)),
          pandoc.Cell(pandoc.Blocks(right)),
        },
      },
      head = {},
      row_head_columns = 0,
    },
  }
  return {
    pandoc.Table(empty_caption(), colspecs, head, bodies, pandoc.TableFoot()),
  }
end

-- The line-items table plus a caption line.
local function items_table(inv)
  local items = inv["items"]
  if not is_list(items) then
    return {}
  end
  local rows = {}
  for _, item in ipairs(items) do
    local desc = item["description"] ~= nil and tostring_meta(item["description"]) or ""
    local qty = item["quantity"] ~= nil and tonumber(tostring_meta(item["quantity"])) or 1
    local unit = item["unit-price"] ~= nil and tostring_meta(item["unit-price"]) or ""
    local unit_pence = parse_pence(item["unit-price"])
    local amount_pence = unit_pence ~= nil and (unit_pence * qty) or nil
    local amount = amount_pence ~= nil and format_pence(amount_pence) or ""
    rows[#rows + 1] = pandoc.Row{
      pandoc.Cell(pandoc.Plain({ pandoc.Str(desc) })),
      pandoc.Cell(pandoc.Plain({ pandoc.Str(tostring(qty)) })),
      pandoc.Cell(pandoc.Plain({ pandoc.Str(unit) })),
      pandoc.Cell(pandoc.Plain({ pandoc.Str(amount) })),
    }
  end
  -- pandoc Table constructor (this pandoc version):
  --   pandoc.Table(caption, colspecs, head, bodies, foot)
  -- Widths are fractions of the content width: description dominant,
  -- quantity narrow, unit price and amount wider than quantity but
  -- narrower than description. Fractions of 0 are treated by LaTeX as
  -- default-width columns, so use small explicit widths instead.
  -- The items table carries no caption. A numbered caption
  -- ("Table 1: Line items") reads as template output on a client
  -- invoice. The table is the only one on the page and needs no label.
  local caption = empty_caption()
  local colspecs = {
    { pandoc.AlignLeft, 0.52 },
    { pandoc.AlignCenter, 0.08 },
    { pandoc.AlignRight, 0.20 },
    { pandoc.AlignRight, 0.20 },
  }
  local head = pandoc.TableHead{
    pandoc.Row{
      pandoc.Cell(pandoc.Plain({ pandoc.Str("Description") })),
      pandoc.Cell(pandoc.Plain({ pandoc.Str("Qty") })),
      pandoc.Cell(pandoc.Plain({ pandoc.Str("Unit price") })),
      pandoc.Cell(pandoc.Plain({ pandoc.Str("Amount") })),
    },
  }
  local bodies = {
    {
      attr = {},
      body = rows,
      head = {},
      row_head_columns = 0,
    },
  }
  local table_block = pandoc.Table(
    caption,
    colspecs,
    head,
    bodies,
    pandoc.TableFoot()
  )
  return {
    table_block,
    pandoc.Para({ pandoc.Emph({ pandoc.Str("All amounts in pounds sterling (GBP).") }) }),
  }
end

-- Subtotal, discount, tax, and total-due, as a right-aligned summary
-- table (label column, amount column) so the money section reads like
-- a commercial invoice rather than body paragraphs.
local function totals_block(inv)
  local items = inv["items"]
  if not is_list(items) then
    return {}
  end
  local total_pence = 0
  for _, item in ipairs(items) do
    local unit_pence = parse_pence(item["unit-price"])
    local qty = item["quantity"] ~= nil and tonumber(tostring_meta(item["quantity"])) or 1
    total_pence = total_pence + ((unit_pence or 0) * qty)
  end
  local rows = {
    pandoc.Row{
      pandoc.Cell(pandoc.Plain({ pandoc.Str("Subtotal") })),
      pandoc.Cell(pandoc.Plain({ pandoc.Str("GBP " .. format_pence(total_pence)) })),
    },
  }
  local discount_pence = inv["discount"] ~= nil and parse_pence(inv["discount"]) or nil
  if discount_pence ~= nil then
    rows[#rows + 1] = pandoc.Row{
      pandoc.Cell(pandoc.Plain({ pandoc.Str("Discount") })),
      pandoc.Cell(pandoc.Plain({ pandoc.Str("- GBP " .. format_pence(math.abs(discount_pence))) })),
    }
    total_pence = total_pence - discount_pence
  end
  local tax_pence = inv["tax"] ~= nil and parse_pence(inv["tax"]) or nil
  if tax_pence ~= nil then
    rows[#rows + 1] = pandoc.Row{
      pandoc.Cell(pandoc.Plain({ pandoc.Str("Adjustment") })),
      pandoc.Cell(pandoc.Plain({ pandoc.Str("- GBP " .. format_pence(math.abs(tax_pence))) })),
    }
    total_pence = total_pence - tax_pence
  end
  -- A spacer row before Total due gives the total breathing room, so
  -- the eye lands on it. The total is the number a client looks for
  -- first; the design should serve that.
  rows[#rows + 1] = pandoc.Row{
    pandoc.Cell(pandoc.Plain({ pandoc.Str("") })),
    pandoc.Cell(pandoc.Plain({ pandoc.Str("") })),
  }
  rows[#rows + 1] = pandoc.Row{
    pandoc.Cell(pandoc.Plain({ pandoc.Strong({ pandoc.Str("Total due") }) })),
    pandoc.Cell(pandoc.Plain({ pandoc.Strong({ pandoc.Str("GBP " .. format_pence(total_pence)) }) })),
  }
  local caption = empty_caption()
  local colspecs = {
    { pandoc.AlignLeft, 0.62 },
    { pandoc.AlignRight, 0.38 },
  }
  local head = pandoc.TableHead{}
  local bodies = {
    {
      attr = {},
      body = rows,
      head = {},
      row_head_columns = 0,
    },
  }
  return {
    pandoc.Table(caption, colspecs, head, bodies, pandoc.TableFoot()),
  }
end

-- The payment block, provider-agnostic.
local function payment_block(inv)
  local payment = inv["payment"]
  if payment == nil then
    return {}
  end
  local blocks = {}
  local terms = payment["terms"]
  if terms ~= nil then
    blocks[#blocks + 1] = kv_para("Terms", tostring_meta(terms))
  end
  -- A VAT status line removes the standard finance-team query. A
  -- below-threshold sole trader has no VAT number and should not print
  -- one. The author sets the exact wording so the line stays accurate
  -- when the business registers for VAT.
  local vat_status = inv["vat-status"]
  if vat_status ~= nil then
    blocks[#blocks + 1] = kv_para("VAT", tostring_meta(vat_status))
  end
  local provider = payment["provider"] ~= nil and tostring_meta(payment["provider"]):lower() or ""
  local link = payment["link"]
  if provider == "bank-transfer" then
    local details = payment["details"]
    if details ~= nil then
      local label_map = {
        { "bank", "Bank" },
        { "sort-code", "Sort code" },
        { "account", "Account number" },
        { "name", "Account name" },
        { "reference", "Payment reference" },
      }
      for _, pair in ipairs(label_map) do
        local val = details[pair[1]]
        if val ~= nil then
          blocks[#blocks + 1] = kv_para(pair[2], tostring_meta(val))
        end
      end
    end
    -- Invoice-fraud defence: bank details are stable. A request to
    -- change them by email is a fraud signal; the client verifies by
    -- phone on a known number. NCA and Stop! Think Fraud guidance.
    blocks[#blocks + 1] = pandoc.Para({
      pandoc.Emph({
        pandoc.Str("We will never change our bank details by email. If you receive such a request, verify by phone on a known number."),
      }),
    })
  elseif link ~= nil and (provider == "stripe" or provider == "paypal" or provider == "generic") then
    blocks[#blocks + 1] = pandoc.Para({
      pandoc.Str("Pay now: "),
      pandoc.Link({ pandoc.Str("pay the invoice online") }, tostring_meta(link)),
    })
  end
  return blocks
end

-- Fail loudly when the invoice is unusable. A missing number, date,
-- client name, or empty items list must stop the render with a clear
-- error instead of silently rendering an empty block or a zero
-- total. An unparseable unit price is the same class of error: the
-- amount column would show GBP 0.00 for a real charge.
local function validate_invoice(inv)
  local function fail(field)
    error("invoice: missing or invalid field '" .. field .. "'")
  end
  if inv["number"] == nil or tostring_meta(inv["number"]) == "" then
    fail("number")
  end
  if inv["date"] == nil or tostring_meta(inv["date"]) == "" then
    fail("date")
  end
  local client = inv["client"]
  if client == nil or tostring_meta(client["name"]) == "" then
    fail("client.name")
  end
  local items = inv["items"]
  if not is_list(items) or #items == 0 then
    fail("items")
  end
  for _, item in ipairs(items) do
    local price = parse_pence(item["unit-price"])
    if price == nil then
      error("invoice: item '" .. tostring_meta(item["description"]) ..
            "' has an unparseable unit price")
    end
  end
end

function Pandoc(doc)
  local meta = doc.meta
  local inv = meta["invoice"]
  if inv == nil then
    return doc
  end
  validate_invoice(inv)
  local generated = {}
  local sender = sender_block(inv, meta)
  for _, b in ipairs(sender) do
    generated[#generated + 1] = b
  end
  local header = header_table(inv)
  for _, b in ipairs(header) do
    generated[#generated + 1] = b
  end
  generated[#generated + 1] = pandoc.HorizontalRule()
  local items = items_table(inv)
  for _, b in ipairs(items) do
    generated[#generated + 1] = b
  end
  local totals = totals_block(inv)
  for _, b in ipairs(totals) do
    generated[#generated + 1] = b
  end
  local payment = payment_block(inv)
  for _, b in ipairs(payment) do
    generated[#generated + 1] = b
  end
  -- Walk the document and fill the marker Div with the generated
  -- content. Other blocks pass through untouched.
  local function fill(items)
    local out = {}
    for _, item in ipairs(items) do
      if item.t == "Div" then
        local classes = item.classes or {}
        local is_marker = false
        for _, c in ipairs(classes) do
          if c == "obsidian-invoice" then
            is_marker = true
          end
        end
        if is_marker then
          item.content = pandoc.List(generated)
          out[#out + 1] = item
        else
          item.content = fill(item.content)
          out[#out + 1] = item
        end
      elseif item.content ~= nil then
        item.content = fill(item.content)
        out[#out + 1] = item
      else
        out[#out + 1] = item
      end
    end
    return out
  end
  doc.blocks = fill(doc.blocks)
  return doc
end

return { { Pandoc = Pandoc } }
