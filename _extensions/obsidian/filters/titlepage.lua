-- SPDX-License-Identifier: MIT
-- Themed title page for the obsidian-pdf format.
--
-- Activation (front matter):
--   titlepage: true           -> plain theme
--   titlepage: false          -> no cover page at all
--   titlepage: <theme>        -> plain | formal | classic-lined |
--                                colorbox | academic | bg-image
--   titlepage: <file.tex>     -> include a custom LaTeX cover file
--
-- Theme tuning lives under `titlepage-theme:` (elements, alignments,
-- font styles, spacing, colours). Direct keys: titlepage-logo,
-- titlepage-header, titlepage-footer, titlepage-bg-image,
-- titlepage-geometry. See docs/reference.md for the field catalogue.
--
-- When the key is absent the standard Obsidian cover page renders, so
-- existing documents are unaffected.

local function isEmpty(s)
  return s == nil or s == ''
end

local function file_exists(name)
  local f = io.open(name, "r")
  if f ~= nil then io.close(f) return true else return false end
end

local function getVal(s)
  return pandoc.utils.stringify(s)
end

local function is_equal(s, val)
  if isEmpty(s) then return false end
  return getVal(s) == val
end

local function has_value(tab, val)
  for _, v in ipairs(tab) do
    if v == val then return true end
  end
  return false
end

function Meta(m)

  -- No titlepage key: leave the standard cover alone.
  if isEmpty(m.titlepage) then return m end

  local function check_yaml(yamlelement, yamltext, okvals)
    local choice = getVal(yamlelement)
    if not has_value(okvals, choice) then
      error("titlepage extension error: " .. yamltext .. " is set to " ..
            choice .. ". It can be " .. table.concat(okvals, ", ") .. ".")
    end
    return true
  end

  -- Record which style variant is active for an element so the TeX
  -- partials can emit the right block definition.
  local function set_style(page, styleelement, okvals)
    local yamltext = page .. "-theme: " .. styleelement .. "-style"
    local yamlelement = m[page .. "-theme"][styleelement .. "-style"]
    if not isEmpty(yamlelement) then
      check_yaml(yamlelement, yamltext, okvals)
      m[page .. "-style-code"][styleelement] = {}
      m[page .. "-style-code"][styleelement][getVal(yamlelement)] = true
    else
      m[page .. "-style-code"][styleelement] = {}
      m[page .. "-style-code"][styleelement]["plain"] = true
    end
  end

  -- Fill theme defaults for keys the user did not set.
  local function assign_value(tab)
    for i, value in pairs(tab) do
      if isEmpty(m["titlepage-theme"][i]) then
        m["titlepage-theme"][i] = value
      end
    end
    return m
  end

  local latex = function(s)
    return pandoc.MetaInlines{pandoc.RawInline("latex", s)}
  end

  local titlepage_table = {
    -- Business-document default: classification, title block, author,
    -- date, logo, identity line.
    ["plain"] = function(m)
      assign_value({
        ["elements"] = {
          latex("\\headerblock"),
          latex("\\logoblock"),
          latex("\\titleblock"),
          latex("\\authorblock"),
          latex("\\vfill"),
          latex("\\dateblock"),
          latex("\\footerblock"),
        },
        ["page-align"] = "left",
        ["title-style"] = "plain",
        ["title-fontstyle"] = {"huge", "bfseries"},
        ["title-space-after"] = "1.5cm",
        ["subtitle-fontstyle"] = {"Large"},
        ["subtitle-space-after"] = "1cm",
        ["title-subtitle-space-between"] = "0.5cm",
        ["author-style"] = "plain-with-and",
        ["author-fontstyle"] = {"Large"},
        ["author-space-after"] = "1cm",
        ["date-fontstyle"] = {"large"},
        ["date-space-after"] = "1cm",
        ["header-space-after"] = "1cm",
        ["logo-size"] = latex("0.27\\textwidth"),
        ["logo-space-after"] = latex("2\\baselineskip"),
      })
      return m
    end,

    -- Centred, heavier title; report cover.
    ["formal"] = function(m)
      assign_value({
        ["elements"] = {
          latex("\\titleblock"),
          latex("\\authorblock"),
          latex("\\vfill"),
          latex("\\dateblock"),
          latex("\\logoblock"),
          latex("\\footerblock"),
        },
        ["page-align"] = "center",
        ["title-style"] = "plain",
        ["title-fontstyle"] = {"Huge", "textbf"},
        ["title-space-after"] = "1.5cm",
        ["subtitle-fontstyle"] = {"LARGE"},
        ["title-subtitle-space-between"] = "0.5cm",
        ["author-style"] = "plain",
        ["author-sep"] = "newline",
        ["author-fontstyle"] = {"textbf"},
        ["author-space-after"] = latex("2\\baselineskip"),
        ["date-fontstyle"] = {"large"},
        ["logo-size"] = latex("0.4\\textwidth"),
        ["logo-space-after"] = "1cm",
      })
      return m
    end,

    -- Rules above and below the title; classic.
    ["classic-lined"] = function(m)
      assign_value({
        ["elements"] = {
          latex("\\titleblock"),
          latex("\\authorblock"),
          latex("\\vfill"),
          latex("\\logoblock"),
          latex("\\footerblock"),
        },
        ["page-align"] = "center",
        ["title-style"] = "doublelinewide",
        ["title-fontsize"] = 30,
        ["title-fontstyle"] = {"uppercase"},
        ["title-space-after"] = latex("0.1\\textheight"),
        ["subtitle-fontstyle"] = {"Large", "textit"},
        ["author-style"] = "plain",
        ["author-sep"] = latex("\\hskip1em"),
        ["author-fontstyle"] = {"Large"},
        ["author-space-after"] = latex("2\\baselineskip"),
        ["logo-size"] = latex("0.25\\textheight"),
        ["logo-space-after"] = "1cm",
      })
      return m
    end,

    -- Title in a colour box; strong cover.
    ["colorbox"] = function(m)
      assign_value({
        ["elements"] = {
          latex("\\titleblock"),
          latex("\\vfill"),
          latex("\\authorblock"),
          latex("\\dateblock"),
        },
        ["page-align"] = "left",
        ["title-style"] = "colorbox",
        ["title-fontsize"] = 40,
        ["title-space-after"] = latex("2\\baselineskip"),
        ["subtitle-fontsize"] = 25,
        ["subtitle-fontstyle"] = {"bfseries"},
        ["title-subtitle-space-between"] = latex("5\\baselineskip"),
        ["author-style"] = "plain",
        ["author-sep"] = "newline",
        ["author-fontstyle"] = {"Large"},
        ["author-align"] = "right",
        ["author-space-after"] = latex("2\\baselineskip"),
        ["title-colorbox-borderwidth"] = "2mm",
        ["title-colorbox-bordercolor"] = "obsidian",
        ["title-colorbox-fill"] = "cream",
      })
      return m
    end,

    -- Journal-style author/affiliation machinery, available for
    -- research-adjacent documents.
    ["academic"] = function(m)
      assign_value({
        ["elements"] = {
          latex("\\headerblock"),
          latex("\\logoblock"),
          latex("\\titleblock"),
          latex("\\authorblock"),
          latex("\\vfill"),
          latex("\\dateblock"),
          latex("\\footerblock"),
        },
        ["page-align"] = "center",
        ["title-style"] = "doublelinetight",
        ["title-fontstyle"] = {"huge", "bfseries"},
        ["title-space-after"] = "1.5cm",
        ["subtitle-fontstyle"] = {"Large"},
        ["author-style"] = "superscript-with-and",
        ["author-fontstyle"] = {"textsc"},
        ["affiliation-style"] = "numbered-list-with-correspondence",
        ["affiliation-fontstyle"] = {"large"},
        ["affiliation-space-after"] = "1pt",
        ["header-fontstyle"] = {"textsc", "LARGE"},
        ["header-space-after"] = "1.5cm",
        ["date-fontstyle"] = {"large"},
        ["logo-size"] = latex("0.25\\textheight"),
        ["logo-space-after"] = latex("2\\baselineskip"),
      })
      return m
    end,

    -- Background image in a corner (or anywhere) behind the content.
    -- The default geometry opens the top margin so a corner image
    -- does not collide with the title under the house 2.6cm margins.
    ["bg-image"] = function(m)
      if isEmpty(m["titlepage-geometry"]) then
        m["titlepage-geometry"] = pandoc.List({"top=5cm", "bottom=2.6cm",
                                              "left=2.4cm", "right=2.4cm"})
      end
      assign_value({
        ["elements"] = {
          latex("\\titleblock"),
          latex("\\authorblock"),
          latex("\\dateblock"),
          latex("\\vfill"),
          latex("\\logoblock"),
          latex("\\footerblock"),
        },
        ["page-align"] = "left",
        ["title-style"] = "plain",
        ["title-fontstyle"] = {"large", "bfseries"},
        ["title-space-after"] = latex("4\\baselineskip"),
        ["subtitle-fontstyle"] = {"large", "textit"},
        ["author-style"] = "plain-with-and",
        ["author-fontstyle"] = {"large"},
        ["author-space-after"] = latex("2\\baselineskip"),
        ["logo-size"] = latex("0.15\\textheight"),
        ["logo-space-after"] = latex("0.1\\textheight"),
        ["bg-image-size"] = latex("0.4\\paperwidth"),
        ["bg-image-location"] = "ULCorner",
      })
      return m
    end,

    -- Full-page colour band behind a white title block, with a
    -- contrast rule. The banded look is a neutral interpretation of
    -- the classic cover: a solid colour field, a rule, and a title
    -- that reads on it. Classification is recolored to white; the
    -- dark house logo is omitted (it would vanish on the band).
    ["banded"] = function(m)
      assign_value({
        ["elements"] = {
          latex("\\titleblock"),
          latex("\\bandrule"),
          latex("\\authorblock"),
          latex("\\dateblock"),
          latex("\\vfill"),
        },
        ["page-align"] = "left",
        ["title-style"] = "plain",
        ["title-fontsize"] = 34,
        ["title-fontstyle"] = {"bfseries"},
        ["title-color"] = "white",
        ["title-space-after"] = latex("2\\baselineskip"),
        ["subtitle-fontsize"] = 18,
        ["subtitle-color"] = "white",
        ["title-subtitle-space-between"] = latex("\\baselineskip"),
        ["author-style"] = "plain-with-and",
        ["author-fontsize"] = 14,
        ["author-color"] = "white",
        ["author-space-after"] = latex("\\baselineskip"),
        ["date-fontsize"] = 12,
        ["date-color"] = "white",
        ["date-space-after"] = "1cm",
        ["band-rule-color"] = "gold",
        ["band-rule-width"] = latex("3pt"),
        ["band-rule-space"] = latex("\\baselineskip"),
        ["page-html-color"] = "522b45",
        ["classification-color"] = "white",
        ["logo-size"] = latex("0.2\\textwidth"),
      })
      return m
    end,

    -- Slate variant of the banded theme.
    ["banded-slate"] = function(m)
      assign_value({
        ["elements"] = {
          latex("\\titleblock"),
          latex("\\bandrule"),
          latex("\\authorblock"),
          latex("\\dateblock"),
          latex("\\vfill"),
        },
        ["page-align"] = "left",
        ["title-style"] = "plain",
        ["title-fontsize"] = 34,
        ["title-fontstyle"] = {"bfseries"},
        ["title-color"] = "white",
        ["title-space-after"] = latex("2\\baselineskip"),
        ["subtitle-fontsize"] = 18,
        ["subtitle-color"] = "white",
        ["title-subtitle-space-between"] = latex("\\baselineskip"),
        ["author-style"] = "plain-with-and",
        ["author-fontsize"] = 14,
        ["author-color"] = "white",
        ["author-space-after"] = latex("\\baselineskip"),
        ["date-fontsize"] = 12,
        ["date-color"] = "white",
        ["date-space-after"] = "1cm",
        ["band-rule-color"] = "yellow",
        ["band-rule-width"] = latex("3pt"),
        ["band-rule-space"] = latex("\\baselineskip"),
        ["page-html-color"] = "313d47",
        ["classification-color"] = "white",
        ["logo-size"] = latex("0.2\\textwidth"),
      })
      return m
    end,
  }

  m["titlepage-file"] = false
  local choice = getVal(m.titlepage)
  if choice == "false" or choice == "none" then
    m["titlepage-true"] = false
    m["titlepage-none"] = true
    return m
  end
  if choice == "true" then choice = "plain" end

  local okvals = {"plain", "formal", "classic-lined", "colorbox", "academic",
                  "bg-image", "banded", "banded-slate"}
  local isatheme = has_value(okvals, choice)
  if not isatheme then
    if not file_exists(choice) then
      error("titlepage extension error: titlepage can be a tex file or one of the themes: " ..
            table.concat(okvals, ", ") .. ".")
    end
    m["titlepage-file"] = true
    m["titlepage-filename"] = choice
    m["titlepage-true"] = true
    return m
  end

  m["titlepage-true"] = true
  if isEmpty(m["titlepage-theme"]) then m["titlepage-theme"] = {} end
  titlepage_table[choice](m)

  -- Style codes, read by the TeX partials to pick block definitions.
  m["titlepage-style-code"] = {}
  okvals = {"none", "plain", "colorbox", "doublelinewide", "doublelinetight"}
  set_style("titlepage", "title", okvals)
  set_style("titlepage", "footer", okvals)
  set_style("titlepage", "header", okvals)
  set_style("titlepage", "date", okvals)
  okvals = {"none", "plain", "plain-with-and", "superscript",
            "superscript-with-and", "two-column", "author-address"}
  set_style("titlepage", "author", okvals)
  okvals = {"none", "numbered-list", "numbered-list-with-correspondence"}
  set_style("titlepage", "affiliation", okvals)

  -- Font sizes: a size without a spacing gets 1.2x (a standard
  -- leading ratio), and an element without a size inherits the page.
  for _, val in pairs({"title", "author", "affiliation", "footer", "header", "date"}) do
    if isEmpty(m["titlepage-theme"][val .. "-fontsize"]) then
      if not isEmpty(m["titlepage-theme"]["page-fontsize"]) then
        m["titlepage-theme"][val .. "-fontsize"] = getVal(m["titlepage-theme"]["page-fontsize"])
      end
    end
  end
  for _, val in pairs({"page", "title", "subtitle", "author", "affiliation",
                       "footer", "header", "date"}) do
    if not isEmpty(m["titlepage-theme"][val .. "-fontsize"]) then
      if isEmpty(m["titlepage-theme"][val .. "-spacing"]) then
        m["titlepage-theme"][val .. "-spacing"] = 1.2 * getVal(m["titlepage-theme"][val .. "-fontsize"])
      end
    end
  end

  -- Author and affiliation separators.
  if isEmpty(m["titlepage-theme"]["author-sep"]) then
    m["titlepage-theme"]["author-sep"] = latex(", ")
  end
  if is_equal(m["titlepage-theme"]["author-sep"], "newline") then
    m["titlepage-theme"]["author-sep"] = latex("\\\\")
  end
  if isEmpty(m["titlepage-theme"]["affiliation-sep"]) then
    m["titlepage-theme"]["affiliation-sep"] = latex(",~")
  end
  if is_equal(m["titlepage-theme"]["affiliation-sep"], "newline") then
    m["titlepage-theme"]["affiliation-sep"] = latex("\\\\")
  end

  -- Alignments: validate what the user set, default the page to left.
  if isEmpty(m["titlepage-theme"]["page-align"]) then
    m["titlepage-theme"]["page-align"] = "left"
  end
  for _, val in pairs({"page", "title", "author", "affiliation", "footer",
                       "header", "logo", "date"}) do
    if not isEmpty(m["titlepage-theme"][val .. "-align"]) then
      local vals = {"right", "left", "center"}
      if has_value({"title", "author", "footer", "header"}, val) then
        table.insert(vals, "spread")
      end
      check_yaml(m["titlepage-theme"][val .. "-align"],
                 "titlepage-theme: " .. val .. "-align", vals)
    end
  end

  -- Background image: the bg-image theme is meaningless without one,
  -- so fail loudly instead of rendering a blank cover. The bundled
  -- corner motif (assets/corner-bg.png) is the natural choice, but
  -- any image works via titlepage-bg-image.
  if choice == "bg-image" and isEmpty(m["titlepage-bg-image"]) then
    error("titlepage extension error: the bg-image theme needs " ..
          "titlepage-bg-image: <file> (try assets/corner-bg.png)")
  end
  if not isEmpty(m["titlepage-bg-image"]) then
    if isEmpty(m["titlepage-theme"]["bg-image-size"]) then
      m["titlepage-theme"]["bg-image-size"] = latex("\\paperwidth")
    end
    if not isEmpty(m["titlepage-theme"]["bg-image-location"]) then
      check_yaml(m["titlepage-theme"]["bg-image-location"],
                 "titlepage-theme: bg-image-location",
                 {"ULCorner", "URCorner", "LLCorner", "LRCorner", "Center"})
    end
  end

  -- Logo defaults: the house mark, sized to the page. Set
  -- `titlepage-logo: false` to omit it entirely.
  if isEmpty(m["titlepage-logo"]) then
    m["titlepage-logo"] = "obsidian-logo.png"
  end
  if not isEmpty(m["titlepage-logo"]) and not is_equal(m["titlepage-logo"], "false") then
    if isEmpty(m["titlepage-theme"]["logo-size"]) then
      m["titlepage-theme"]["logo-size"] = latex("0.2\\paperwidth")
    end
  end

  -- House palette defaults: brand near-black primary, grey secondary.
  -- Themes may override per element.
  assign_value({
    ["title-color"] = "obsidian",
    ["subtitle-color"] = "obsidianl",
    ["author-color"] = "obsidian",
    ["affiliation-color"] = "obsidianl",
    ["footer-color"] = "obsidianl",
    ["header-color"] = "obsidianl",
    ["date-color"] = "obsidianl",
  })

  return m
end
