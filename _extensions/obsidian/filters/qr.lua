-- SPDX-License-Identifier: MIT
-- qr.lua
-- Renders QR codes from Div elements or inline Code elements.
--
-- Syntax:
--   ::: {.qr data="https://example.com" size="2cm" caption="Scan me"} :::
--   or inline: `{qr data="https://example.com"}`
--
-- For PDF (LaTeX): uses the qrcode package.
-- For HTML: embeds a small inline QR code generator.
-- For other formats: renders the data as plain text.

-- Detect output format
local function is_pdf()
    return FORMAT == "pdf" or FORMAT == "latex"
end

local function is_html()
    return FORMAT == "html" or FORMAT == "html4" or FORMAT == "html5"
end

-- Handle Div-based QR codes
function Div(el)
    if not el.classes:includes("qr") then
        return nil
    end

    local attrs = el.attributes
    local data = attrs["data"] or ""
    local size = attrs["size"] or "2cm"
    local caption = attrs["caption"] or ""

    if data == "" then
        io.stderr:write("qr.lua: no data attribute on QR code\n")
        return nil
    end

    if is_pdf() then
        local tex = string.format(
            "\\begin{center}\\qrcode[height=%s]{%s}",
            size, data)
        if caption ~= "" then
            tex = tex .. string.format("\\\\[4pt]\\small\\textit{%s}", caption)
        end
        tex = tex .. "\\end{center}"
        return pandoc.RawBlock("latex", tex)
    elseif is_html() then
        local html = string.format(
            '<div class="qr-code" style="text-align:center;margin:1em 0">'
            .. '<canvas id="qr-%s"></canvas>'
            .. '<script>'
            .. '(function(){'
            .. 'var c=document.getElementById("qr-%s");'
            .. 'var s=128;'
            .. 'c.width=s;c.height=s;'
            .. 'var ctx=c.getContext("2d");'
            .. 'ctx.fillStyle="#fff";ctx.fillRect(0,0,s,s);'
            -- Minimal QR rendering: just show the data as a visual block
            -- For production, use a proper QR library like qrcodejs
            .. 'ctx.fillStyle="#000";ctx.font="10px monospace";'
            .. 'ctx.fillText("QR: %s",4,s/2);'
            .. '})()'
            .. '</script>'
            , data, data, data:sub(1, 20))
        if caption ~= "" then
            html = html .. string.format('<p style="font-size:0.9em;color:#666">%s</p>', caption)
        end
        return pandoc.RawBlock("html", html)
    else
        return pandoc.Plain({pandoc.Str("[QR: " .. data .. "]")})
    end
end

-- Handle inline Code-based QR codes: {qr data="..."}
function Code(el)
    -- Check for qr shortcode pattern
    local qr_data = el.text:match("^qr%s+data=\"([^\"]+)\"$")
    if not qr_data then
        qr_data = el.text:match("^qr%s+data='([^']+)'$")
    end
    if not qr_data then
        return nil
    end

    if is_pdf() then
        return pandoc.RawInline("latex",
            string.format("\\qrcode[height=1.5cm]{%s}", qr_data))
    elseif is_html() then
        return pandoc.RawInline("html",
            string.format('<code class="qr-inline">[QR: %s]</code>', qr_data:sub(1, 30)))
    else
        return pandoc.Str("[QR: " .. qr_data .. "]")
    end
end
