-------------------------------------------------------------------------------
-- awesome_pass_spec.lua for awesome-pass                                    --
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
-- unit tests for awesome-pass
-- }}}

--- awesome_pass_spec -- {{{
package.path = "./tests/mocks/?.lua;" .. package.path

local pass  = require('awesome-pass')
local awful = require('awful')

describe("awesome-pass tests", function ()
  describe("toggle_pass_menu tests", function ()
      it("should build a new pass_menu when none exists", function ()
         local base = {}
         function base:buttons(...) end
         local p = pass.new(base)
         awful.spawn.set_callback_values(io.open("./tests/test.txt"):read("*all"),"",
                                         "exit",0)
         assert.is_nil(p.pass_menu)
         p:toggle_pass_menu()
    end)
  end)
end)

-- }}}
