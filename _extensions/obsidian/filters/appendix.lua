-- SPDX-License-Identifier: MIT
-- appendix.lua
-- Converts a heading with the class `appendix` into the LaTeX
-- \appendix switch followed by the heading itself.
--
-- The switch is emitted only before the first such heading. LaTeX
-- then numbers subsequent sections A, B, C and registers them in the
-- table of contents automatically.
--
-- Author usage:
--   # Compliance Matrix {.appendix}

local switched = false

function Header(el)
  if not switched and el.classes:includes('appendix') then
    switched = true
    return { pandoc.RawBlock('latex', '\\appendix'), el }
  end
end
