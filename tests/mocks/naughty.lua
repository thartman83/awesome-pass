-------------------------------------------------------------------------------
-- naughty.lua for awesome-pass                                              --
-- Copyright (c) 2017 Tom Hartman (thomas.lees.hartman@gmail.com)            --
--                                                                           --
-- This program is free software; you can redistribute it and/or             --
-- modify it under the terms of the GNU General Public License               --
-- as published by the Free Software Foundation; either version 2            --
-- of the License, or the License, or (at your option) any later             --
-- version.                                                                  --
--                                                                           --
-- This program is distributed in the hope that it will be useful,           --
-- but WITHOUT ANY WARRANTY; without even the implied warranty of            --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the             --
-- GNU General Public License for more details.                              --
-------------------------------------------------------------------------------

--- Commentary -- {{{
-- naughty stubs and mocks for awesome-pass tests
-- }}}

local naughty = {}

--- naughty.notify -- {{{
----------------------------------------------------------------------
-- Mock function for naughty.notify, instead of displaying an alert,
-- dump the contents of the args table to stdout
-- @param args
----------------------------------------------------------------------
function naughty.notify (args)
   for k,v in args do
      print(k .. ": " .. v)
   end
end
-- }}}

--- naughty  -- {{{
return naughty
-- }}}
