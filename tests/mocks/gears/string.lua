-- These functions are lifted directly from awesome 4.1
-- gears/string.lua

-- gears.string
local gstring = {}

--- Escape all special pattern-matching characters so that lua interprets them
-- literally instead of as a character class.
-- Source: http://stackoverflow.com/a/20778724/15690
-- @class function
-- @name quote_pattern
function gstring.quote_pattern(s)
    -- All special characters escaped in a string: %%, %^, %$, ...
    local patternchars = '['..("%^$().[]*+-?"):gsub("(.)", "%%%1")..']'
    return string.gsub(s, patternchars, "%%%1")
end

return gstring
