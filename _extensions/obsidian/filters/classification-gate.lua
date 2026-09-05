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
--   - accepts `confidentiality` or `classification` (the field name
--     used by GSCP-style templates, so they drop in unchanged)
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
  -- NATO levels (used in dual markings)
  ["NATO UNCLASSIFIED"] = true,
  ["NATO RESTRICTED"] = true,
  ["NATO CONFIDENTIAL"] = true,
  ["NATO SECRET"] = true,
  ["COSMIC TOP SECRET"] = true,
}

local OBSOLETE = {
  ["RESTRICTED"] = true,
  ["CONFIDENTIAL"] = true,
}

-- Valid dual marking separators (UK // NATO)
local DUAL_SEPARATOR = '%s*//%s*'

local function stringify(v)
  return pandoc.utils.stringify(v or '')
end

local function gscp_enabled(meta)
  local flag = meta['gscp']
  if flag then
    -- MetaBool: YAML `gscp: true` renders as MetaBool in pandoc
    if type(flag) == 'boolean' then
      return flag
    end
    if flag.t == 'MetaBool' then
      return flag.c
    end
    local s = stringify(flag):lower()
    return s == 'true' or s == 'yes' or s == 'on'
  end
  -- Auto-enable GSCP when a classification is set.
  -- This ensures classified documents are always validated.
  local marking = stringify(meta['confidentiality'] or meta['classification'] or '')
  if marking ~= '' then
    return true
  end
  return false
end

local function validate_level(level)
  if OBSOLETE[level] then
    return nil, 'obsolete'
  end
  if VALID[level] then
    return true, nil
  end
  return nil, 'unknown'
end

function Pandoc(doc)
  if not gscp_enabled(doc.meta) then
    return doc
  end

  local marking = stringify(doc.meta['confidentiality'] or doc.meta['classification'] or '')

  if marking == '' then
    doc.meta['confidentiality'] = pandoc.MetaString('OFFICIAL')
    io.stderr:write(
      'classification-gate: no marking set; defaulted to OFFICIAL (GSCP v2.0)\n')
    return doc
  end

  -- Check for dual marking (UK // NATO)
  local uk_level, nato_level = marking:upper():match('^(.-)' .. DUAL_SEPARATOR .. '(.+)$')

  if uk_level and nato_level then
    -- Dual marking: validate both levels
    uk_level = uk_level:gsub('%s+', ' ')
    nato_level = nato_level:gsub('%s+', ' ')

    local uk_ok, uk_err = validate_level(uk_level)
    if uk_ok == nil then
      error('classification-gate: UK level "' .. uk_level .. '" is ' .. uk_err
        .. '. GSCP v2.0 levels: OFFICIAL, OFFICIAL-SENSITIVE, SECRET, TOP SECRET.')
    end

    local nato_ok, nato_err = validate_level(nato_level)
    if nato_ok == nil then
      error('classification-gate: NATO level "' .. nato_level .. '" is ' .. nato_err
        .. '. NATO levels: NATO UNCLASSIFIED, NATO RESTRICTED, NATO CONFIDENTIAL, '
        .. 'NATO SECRET, COSMIC TOP SECRET.')
    end

    -- Check for obsolete levels in either part
    if uk_err == 'obsolete' then
      error('classification-gate: "' .. uk_level
        .. '" is an obsolete classification. RESTRICTED and CONFIDENTIAL '
        .. 'no longer exist in the GSCP.')
    end
    if nato_err == 'obsolete' then
      error('classification-gate: "' .. nato_level
        .. '" is an obsolete classification. RESTRICTED and CONFIDENTIAL '
        .. 'no longer exist in NATO.')
    end

    doc.meta['confidentiality'] = pandoc.MetaString(marking)

    if uk_level == 'SECRET' or uk_level == 'TOP SECRET'
      or nato_level == 'NATO SECRET' or nato_level == 'COSMIC TOP SECRET' then
      io.stderr:write('classification-gate: WARNING "' .. marking
        .. '" - SECRET/TOP SECRET handling (secure storage, clearance, '
        .. 'approved transmission) is outside this template. Confirm the '
        .. 'handling arrangements before release.\n')
    end

    return doc
  end

  -- Single marking: validate as before
  local base = marking:upper():gsub('%s*:.*$', ''):gsub('%s+', ' ')

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
