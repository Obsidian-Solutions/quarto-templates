-- review-overdue.lua
-- Enforces JSP 945 review discipline: if the front-matter
-- `review-date` (YYYY-MM-DD) is before the render date, the
-- document carries a prominent REVIEW OVERDUE warning.
--
-- PDF: a LaTeX callout-style warning at the top of the body.
-- HTML: a styled banner div.
-- Other formats: a plain paragraph.

local function stringify(v)
  return pandoc.utils.stringify(v or '')
end

-- Parse YYYY-MM-DD, or 'Month YYYY', to a comparable numeric value.
local months = {
  January = 1, February = 2, March = 3, April = 4, May = 5, June = 6,
  July = 7, August = 8, September = 9, October = 10, November = 11,
  December = 12
}

local function parse_date(s)
  local y, m, d = s:match('(%d%d%d%d)%-(%d%d)%-(%d%d)')
  if y then
    return tonumber(y) * 10000 + tonumber(m) * 100 + tonumber(d)
  end
  local mon, y2 = s:match('(%a+)%s+(%d%d%d%d)')
  if mon and months[mon] then
    -- Overdue only when the whole month has passed.
    return tonumber(y2) * 10000 + months[mon] * 100 + 99
  end
  return nil
end

function Pandoc(doc)
  local review = stringify(doc.meta['review-date'])
  if review == '' then
    return doc
  end
  local review_num = parse_date(review)
  if not review_num then
    return doc
  end
  local today = os.date('%Y-%m-%d')
  local today_num = parse_date(today)
  if today_num <= review_num then
    return doc
  end

  local text = 'REVIEW OVERDUE: this document passed its review date ('
    .. review .. ') and may no longer reflect current policy.'

  local block
  if FORMAT == 'latex' then
    block = pandoc.RawBlock('latex',
      '\\begin{tcolorbox}[colback=white, colframe=obsidian, ' ..
      'coltext=obsidian, left=2mm, leftrule=.75mm, arc=0pt, ' ..
      'title={\\small\\bfseries Review overdue}]' ..
      '\\small ' .. text .. '\\end{tcolorbox}')
  elseif FORMAT == 'html' then
    block = pandoc.RawBlock('html',
      '<div class="obsidian-review-overdue">' .. text .. '</div>')
  else
    block = pandoc.Para({ pandoc.Str(text) })
  end

  table.insert(doc.blocks, 1, block)
  return doc
end
