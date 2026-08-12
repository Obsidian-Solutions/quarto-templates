-- SPDX-License-Identifier: MIT
-- classification-gate.lua
-- Optional validation gate for the UK Government Security
-- Classifications Policy (GSCP v2.0, 5 Aug 2024).
--
-- OFF by default. Documents without `gscp: true` in the front
-- matter are untouched, so every existing document keeps working
-- unchanged. The validation is available for anyone who needs the
-- GSCP, without making it the template's identity.
--
-- When gscp mode is on:
--   - accepts `confidentiality` or `classification` (the MOD field
--     name, so mod-govuk-style templates drop in unchanged)
--   - resolves the default marking to OFFICIAL when none is set
--     (GSCP: OFFICIAL is the default level)
--   - fails the render on obsolete levels (RESTRICTED, CONFIDENTIAL)
--     or any value outside the GSCP set
--   - accepts an OFFICIAL-SENSITIVE reason after a colon, for example
--     "OFFICIAL-SENSITIVE: COMMERCIAL"
--   - warns when SECRET or TOP SECRET is used, because their
--     handling requirements (secure storage, clearance, approved
--     transmission) are outside what a document template can enforce
--
-- The resolved marking is written back to doc.meta['confidentiality'],
-- so the banner filters and the LaTeX cover/header render it exactly
-- once, in one form.

local VALID = {
  ["OFFICIAL"] = true,
  ["OFFICIAL-SENSITIVE"] = true,
  ["SECRET"] = true,
  ["TOP SECRET"] = true,
}

local OBSOLETE = {
  ["RESTRICTED"] = true,
  ["CONFIDENTIAL"] = true,
}

local function stringify(v)
  return pandoc.utils.stringify(v or '')
end

local function gscp_enabled(meta)
  local flag = meta['gscp']
  if not flag then
    return false
  end
  if flag.t == 'MetaBool' then
    return flag.c
  end
  local s = stringify(flag):lower()
  return s == 'true' or s == 'yes' or s == 'on'
end

function Pandoc(doc)
  if not gscp_enabled(doc.meta) then
    return doc
  end

  local marking = stringify(doc.meta['confidentiality'] or doc.meta['classification'] or '')
  local base = marking:upper():gsub('%s*:.*$', ''):gsub('%s+', ' ')

  if marking == '' then
    doc.meta['confidentiality'] = pandoc.MetaString('OFFICIAL')
    io.stderr:write(
      'classification-gate: no marking set; defaulted to OFFICIAL (GSCP v2.0)\n')
    return doc
  end

  if OBSOLETE[base] then
    error('classification-gate: "' .. marking
      .. '" is an obsolete classification. RESTRICTED and CONFIDENTIAL '
      .. 'no longer exist in the GSCP. Use OFFICIAL, OFFICIAL-SENSITIVE, '
      .. 'SECRET or TOP SECRET.')
  end

  if not VALID[base] then
    error('classification-gate: unknown marking "' .. marking
      .. '". GSCP v2.0 levels: OFFICIAL, OFFICIAL-SENSITIVE, SECRET, '
      .. 'TOP SECRET. OFFICIAL-SENSITIVE takes a reason after a colon, '
      .. 'for example "OFFICIAL-SENSITIVE: COMMERCIAL".')
  end

  doc.meta['confidentiality'] = pandoc.MetaString(marking)

  if base == 'SECRET' or base == 'TOP SECRET' then
    io.stderr:write('classification-gate: WARNING "' .. marking
      .. '" - SECRET/TOP SECRET handling (secure storage, clearance, '
      .. 'approved transmission) is outside this template. Confirm the '
      .. 'handling arrangements before release.\n')
  end

  return doc
end
