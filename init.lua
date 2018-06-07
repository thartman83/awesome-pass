-------------------------------------------------------------------------------
-- init.lua for awesome-pass                                                 --
-- Copyright (c) 2017 Tom Hartman (thartman@hudco.com)                       --
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
-- Init file for awesome-pass
-- }}}

--- awesome-pass -- {{{

--- Libraries -- {{{
local setmetatable = setmetatable
local color        = require('gears.color' )
local wibox        = require('wibox'       )
local cairo        = require('lgi'         )
local pango        = require('lgi'         ).Pango
local pangocairo   = require('lgi'         ).PangoCairo
local awful        = require('awful'       )
local gtable       = require('gears.table' )
local gstring      = require('gears.string')
local beautiful    = require('beautiful'   )
local radical      = require('radical'     )
-- }}}

local pass = {}

--- Helper Functions -- {{{

--- gstring.lines -- {{{
----------------------------------------------------------------------
-- splits multi-line string `str' into a table of strings by newline
-- returns an empty table if `str' is nil
----------------------------------------------------------------------
function gstring.lines(str)
   if str == nil then return {} end

   local retval = {}
   local function helper(line) table.insert(retval, line) return "" end
   helper((str:gsub("(.-)\r?\n", helper)))
   return retval
end
-- }}}

--- gstring.split() -- {{{
----------------------------------------------------------------------
-- Return a table of strings 
----------------------------------------------------------------------
function gstring.split(str, delim, noblanks)
   if str == nil then return {} end

   local retval = {}
   local function helper(part) table.insert(retval, part) return "" end
   helper((str:gsub("(.-)" .. delim, helper)))

   return noblanks and gtable.remove_blanks(retval) or retval      
end
-- }}}

--- gtable.remove_blanks -- {{{
----------------------------------------------------------------------
-- Returns a table with all blank strings or tables removed
----------------------------------------------------------------------
function gtable.remove_blanks (t)
   local retval = {}

   for k,v in pairs(t) do
      if not (v == nil or v == '' or
             (type(v) == "table" and next(v) == nil)) then
         retval[k] = v
      end
   end

   return retval
end
-- }}}

-- }}}

--- bat:fit -- {{{
----------------------------------------------------------------------
-- 
----------------------------------------------------------------------
function pass:fit (ctx, width, height)
   return self._width, height
end
-- }}}

--- bat:draw -- {{{
----------------------------------------------------------------------
-- 
----------------------------------------------------------------------
function pass:draw (w, cr, width, height)
   cr:set_source(color(self._color or beautiful.fg_normal))

   cr:move_to(width * .5, height * .5)
   cr:line_to(width * .5, height * .8)
   
   cr:stroke()
end
-- }}}

--- parse_pass_tree -- {{{
----------------------------------------------------------------------
-- 
----------------------------------------------------------------------
function parse_pass_tree (menu, passlist, root)
   local i,v = next(passlist)
   local next_menu, next_root


   print("Parsing " .. v)
      
   -- if the next pass entry is blank return
   -- if the next pass entry is at the wrong level return
   if v == nil or root ~= v:sub(1, #root) then
      return menu
   end

   table.remove(passlist,1)
   
   local parts = gstring.split(v:sub(#root + 2),"/")
   print("Found " .. #parts .. " in " .. v:sub(#root + 2))
   
   if #parts == 1 then      
      menu:add_item { text=gstring.split(parts[1],"%.")[1] }
   else      
      local smenu = parse_pass_tree(radical.context{style=radical.style.classic,
                                                   item_style=radical.classic}, passlist,
                                    root .. "/" .. parts[1])
      menu:add_item { text=parts[1],
                      sub_menu = smenu }
   end
   
   return parse_pass_tree(menu, passlist, root)
end
-- }}}


--- pass:build_pass_menu -- {{{
----------------------------------------------------------------------
-- Build the pass menu based on the given output in stdout
----------------------------------------------------------------------
function pass:build_pass_menu (stdout, stderr, exit_reason, exit_code)
   self._menu = radical.context{style=radical.style.classic,
                                    item_style=radical.item.style.classic}
   self._menu:add_item{ text = "New ..."}

   local passlist = gstring.lines(stdout)

   -- The first line of the tree output is the root directory
   local passroot = table.remove(passlist, 1)
   
   parse_pass_tree(self._menu, passlist, passroot)
   self._menu.parent_geometry = rawget(self, "widget_geo")
   self._menu.visible = true
end
-- }}}

--- pass:toggle_menu -- {{{
----------------------------------------------------------------------
-- Show or close the pass menu
----------------------------------------------------------------------
function pass:toggle_menu ()
   if self._menu ~= nil and self._menu.visible then
      self._menu:hide()
   else 
      awful.spawn.easy_async(self.tree_cmd .. " " .. self.tree_cmd_args ..
                                " " .. self.pass_store,
                             function(s,e,exr,exc)
                                self:build_pass_menu(s,e,exr,exc)
      end)
   end
   
end
-- }}}

--- new -- {{{
----------------------------------------------------------------------
-- build a new pass widget
----------------------------------------------------------------------
local function new (args)
   local obj = wibox.widget.base.empty_widget()
   gtable.crush(obj, pass, true)

   local args = args or {}

   obj.pass_store     = args.pass_store or "/home/" .. os.getenv("USER") ..
      "/.password-store"
   obj.tree_cmd       = "/usr/bin/tree"
   obj.tree_cmd_args  = "--noreport -F -i -f"
   obj.pass_cmd       = "/usr/bin/pass"
   obj.pass_show_args = "-c"
   obj.pass_gen_len   = 16
   obj:buttons(gtable.join(awful.button({}, 1,
                              function () obj:toggle_menu() end)))

   local pl = pango.Layout.new(pangocairo.font_map_get_default():create_context())
   pl:set_font_description(beautiful.get_font(beautiful and beautiful.font))
   pl.text = " H "
   obj._width = pl:get_pixel_extents().width

   return obj
end
-- }}}

return setmetatable(pass, {__call = function(_,...) return new(...) end})
-- }}}
