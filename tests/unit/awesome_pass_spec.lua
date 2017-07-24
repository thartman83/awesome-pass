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
  describe("parse_pass_list tests", function ()
    it("should parse the tree password data", function ()
      local base = {}
      function base:buttons(...) end
      local p = pass(base)
      
      local t = io.open("./tests/test.txt"):read("*all")
      local pass_menu = p:parse_pass_list(t)
      assert.is_not_nil(pass_menu)
      assert.are.same(3, table.getn(pass_menu))
    end)
  end)
  
  describe("build_pass_menu tests", function ()
      it("should build a new pass_menu when none exists", function ()
         local base = {}
         function base:buttons(...) end
         local p = pass(base)

         local t = io.open("./tests/test.txt"):read("*all")

         assert.is_nil(p.pass_menu)
         p:build_pass_table(t)

         assert.is_not_nil(p.pass_menu)
         assert.equals(3, #p.pass_menu.items)
         assert.equals("keys",     p.pass_menu.items[1][1])
         assert.equals("table",    type(p.pass_menu.items[2]))
         assert.equals("a.gpg",    p.pass_menu.items[1][2][1][1])
         assert.equals("function", type(p.pass_menu.items[1][2][1][2]))
         assert.equals("b.gpg",    p.pass_menu.items[1][2][2][1])
         assert.equals("function", type(p.pass_menu.items[1][2][2][2]))
         assert.equals("misc",     p.pass_menu.items[2][1])
         assert.equals("function", type(p.pass_menu.items[2][1][1]))         
         assert.equals("root.gpg", p.pass_menu.items[3][1])
         assert.equals("function", type(p.pass_menu.items[3][2]))
    end)
  end)
end)

-- }}}
