-- SPDX-License-Identifier: MIT
-- form-fields.lua
-- Renders AcroForm fields from Pandoc Div elements.
--
-- Syntax in .qmd:
--   ::: {.form-text name="field-name" label="Label" width="200"}
--   :::
--
--   ::: {.form-checkbox name="check-name" label="Label"}
--   :::
--
--   ::: {.form-dropdown name="drop-name" label="Label" options="opt1,opt2,opt3"}
--   :::
--
-- For PDF (LaTeX): emits hyperref form field commands.
-- For HTML: emits native <input> / <select> elements.
-- For other formats: emits the label as plain text.

-- Form field type constants
local FORM_TEXT = "form-text"
local FORM_CHECKBOX = "form-checkbox"
local FORM_RADIO = "form-radio"
local FORM_DROPDOWN = "form-dropdown"
local FORM_SIGNATURE = "form-signature"

-- Detect output format
local function is_pdf()
    return FORMAT == "pdf" or FORMAT == "latex"
end

local function is_html()
    return FORMAT == "html" or FORMAT == "html4" or FORMAT == "html5"
end

-- Render a form field Div to Pandoc elements
function Div(el)
    local classes = el.classes
    local attrs = el.attributes

    local field_type = nil
    if classes:includes(FORM_TEXT) then
        field_type = "text"
    elseif classes:includes(FORM_CHECKBOX) then
        field_type = "checkbox"
    elseif classes:includes(FORM_RADIO) then
        field_type = "radio"
    elseif classes:includes(FORM_DROPDOWN) then
        field_type = "dropdown"
    elseif classes:includes(FORM_SIGNATURE) then
        field_type = "signature"
    else
        return nil -- not a form field
    end

    local name = attrs["name"] or "unnamed"
    local label = attrs["label"] or name
    local width = attrs["width"] or "200"
    local value = attrs["value"] or ""

    if is_pdf() then
        return render_pdf(field_type, name, label, width, value, attrs)
    elseif is_html() then
        return render_html(field_type, name, label, width, value, attrs)
    else
        return render_plain(field_type, name, label)
    end
end

function render_pdf(ftype, name, label, width, value, attrs)
    local tex_label = pandoc.system.nativeToMarkdown({pandoc.Str(label)})
    if ftype == "text" then
        local w = math.floor(tonumber(width) * 0.85) -- approx pt to chars
        return pandoc.RawBlock("latex",
            string.format("\\noindent\\textbf{%s}: \\TextField[name=%s,width=%dpt,height=18pt]{}\\\\",
                tex_label, name, tonumber(width)))
    elseif ftype == "checkbox" then
        return pandoc.RawBlock("latex",
            string.format("\\noindent\\CheckBox[name=%s,width=12pt,height=12pt]{} \\textbf{%s}\\\\",
                name, tex_label))
    elseif ftype == "radio" then
        local group = attrs["group"] or name
        return pandoc.RawBlock("latex",
            string.format("\\noindent\\RadioButton[name=%s,radio=%s,width=12pt,height=12pt]{} \\textbf{%s}\\\\",
                name, group, tex_label))
    elseif ftype == "dropdown" then
        local options = attrs["options"] or ""
        return pandoc.RawBlock("latex",
            string.format("\\noindent\\textbf{%s}: \\ChoiceMenu[name=%s,width=%dpt]{%s}\\\\",
                tex_label, name, tonumber(width), options))
    elseif ftype == "signature" then
        return pandoc.RawBlock("latex",
            string.format("\\noindent\\textbf{%s}: \\TextField[name=%s,width=%dpt,height=40pt,bordercolor={0 0 0}]{}\\\\",
                tex_label, name, tonumber(width)))
    end
    return nil
end

function render_html(ftype, name, label, width, value, attrs)
    local tag = ""
    local extra = ""
    if ftype == "text" then
        tag = string.format('<input type="text" name="%s" id="%s" value="%s" style="width:%spx" />',
            name, name, value, width)
    elseif ftype == "checkbox" then
        local checked = value == "true" and ' checked' or ''
        tag = string.format('<input type="checkbox" name="%s" id="%s"%s />',
            name, name, checked)
    elseif ftype == "radio" then
        local group = attrs["group"] or name
        tag = string.format('<input type="radio" name="%s" id="%s" value="%s" />',
            group, name, name)
    elseif ftype == "dropdown" then
        local options = attrs["options"] or ""
        local items = {}
        for opt in string.gmatch(options, "[^,]+") do
            table.insert(items, string.format('<option value="%s">%s</option>', opt, opt))
        end
        tag = string.format('<select name="%s" id="%s">%s</select>',
            name, name, table.concat(items))
    elseif ftype == "signature" then
        tag = string.format('<input type="text" name="%s" id="%s" placeholder="Signature" style="width:%spx;border-bottom:1px solid #000" />',
            name, name, width)
    end

    local html = string.format('<div class="form-field" style="margin:8px 0"><label for="%s"><strong>%s</strong></label><br/>%s</div>',
        name, label, tag)
    return pandoc.RawBlock("html", html)
end

function render_plain(ftype, name, label)
    return pandoc.Plain({pandoc.Strong(label), pandoc.Str(": [")})
end
