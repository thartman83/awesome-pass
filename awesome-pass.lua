--- awesome-pass.lua --- Pass widget for awesome

-- Copyright (c) 2016 Thomas Hartman (thomas.lees.hartman@gmail.com)

-- This program is free software- you can redistribute it and/or
-- modify it under the terms of the GNU General Public License
-- as published by the Free Software Foundation- either version 2
-- of the License, or the License, or (at your option) any later
-- version.

-- This program is distributed in the hope that it will be useful
-- but WITHOUT ANY WARRANTY- without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.

local setmetatable = setmetatable
-- local lut          = require('lua-utils.table' )
-- local lus          = require('lua-utils.string')
local awful        = require('awful'           )
local radical      = require('radical'         )
local naughty      = require('naughty'         )
local gstring      = require('gears.string'    )
local gtable       = require('gears.table'     )
-- local md5          = require('md5'             )

require('pl.stringx').import()
local pass = { mt = {} }

--- Helper functions
-- {{{
local function lines(str)
   local t = {}
   local function helper(line) table.insert(t, line) return "" end
   helper((str:gsub("(.-)\r?\n", helper)))
   return t
end

local function split(str, delim, noblanks)
   if str == nil then return {} end

   local t = {}
   local function helper(part) table.insert(t, part) return "" end   
   helper((str:gsub("(.-)" .. delim, helper)))

   if noblanks then
      return remove_blanks(t)
   else
      return t
   end
end

local function remove_blanks(t)
   local retval = {}
   for _, s in ipairs(t) do
      if s ~= "" and s ~= nil then
         table.insert(retval, s)
      end
   end   
   return retval
end
-- }}}

--- Private Pass functions
-- {{{
local function gen_pass (_pass, pass_name)
   local retval = awful.util.spawn(_pass.pass_cmd .. " generate " ..
                                      _pass.pass_gen_args .. " " .. pass_name ..
                                      " " .. _pass.pass_gen_len)
   
   naughty.notify({title="Pass Generation", text = "Done", timeout = 10})
end
-- }}}

--- Public Methods
-- {{{

--- pass_show_callback -- {{{
----------------------------------------------------------------------
-- Call back function for pass show $ENTRY
--
-- @param stdout standard output from the command
-- @param stderr standard error output from the command
-- @param exitreason reason the program exited (exit code or signal)
-- @param exitcode exit code value (or signal code)
----------------------------------------------------------------------
function pass_show_callback (stdout,stderr,exitreason,exitcode)
   
end
-- }}}

--- pass:show_pass_func -- {{{
----------------------------------------------------------------------
-- Return a function that makes an asynchronous call to pass, using
-- the default pass show values.
-- 
-- @param entry entry in the password store to create the
-- function for
----------------------------------------------------------------------
function pass:show_pass_func (entry)
   local cmd = self.pass_cmd .. " show " .. self.pass_show_args .. " " .. entry
   
   return
      function ()
         awful.spawn.easy_async(cmd, pass_show_callback)
      end
end
-- }}}

--- pass_store_has_changed -- {{{
----------------------------------------------------------------------
-- Returns true if the password store has been modified since the last
-- time that the pass_table was built, false otherwise.  NOTE: this
-- returns true only if the structure of the password store has
-- changed, not the actual contents of already existing items
-- @param pass_tree_data output from the `tree' call on the
--                       password-store
----------------------------------------------------------------------
function pass:pass_store_has_changed (pass_tree_data)
   return false
--   return not self.pass_md5 == md5.sumhexa(pass_tree_data)
end
-- }}}

--- pass:build_pass_table -- {{{
----------------------------------------------------------------------
-- Builds a table from the entries in the password-store tree
-- @param pass_tree_data output from the `tree' call on the
--                       password-store
----------------------------------------------------------------------
function pass:build_pass_table (pass_list)
   self.pass_menu = radical.context{style=radical.style.classic,
                                    item_style=radical.item.style.classic}
   self.pass_menu:add_item{text="New ..."}

   local submenu_tbl = {}
   submenu_tbl[""] = self.pass_menu

   for _,v in ipairs(pass_list) do
      print("Processing " .. v)
      
      local parts = split(v,"/")
      local name = table.remove(parts)
      local path = table.concat(parts,"/")

      -- check to see if we've hit a path entry
      if name == "" then
         submenu_tbl[path] = radical.context{style=radical.style.classic,
                                             item_style=radical.item.style.classic}
         local new_menu_name = table.remove(parts)
         local menu_root = table.concat(parts,"/")
         print("Adding new menu " .. new_menu_name .. " to `" ..
                  menu_root .. "' with path " .. path)
         submenu_tbl[menu_root]:add_item{text = new_menu_name,
                                           sub_menu = submenu_tbl[path]}

      else -- this should be a path entry, so add it to the appropriate submenu
         submenu_tbl[path]:add_item{text=split(name,"%.")[1],
                                    button1=self:show_pass_func(v)}
      end
   end
end
-- }}}

--- pass:show_pass_menu_callback -- {{{
----------------------------------------------------------------------
-- 
----------------------------------------------------------------------
function pass:show_pass_menu_callback (stdout, stderr, exitreason, exitcode)
   if exitcode ~= 0 then
      return
   end   

   -- Strip the root password-store information
   local pass_list = stdout:gsub(gstring.quote_pattern(self.pass_store .. "/"),"")
   -- Split the result into lines
   local pass_lines = split(pass_list,"\n")
   -- pop the leading and trailing blank lines
   table.remove(pass_lines,1)
   table.remove(pass_lines)
   
   self:build_pass_table(pass_lines)
   self.pass_menu.visible = true
end
-- }}}

--- pass:generate_pass -- {{{
----------------------------------------------------------------------
-- Add a new password to the password store via the awful prompt box
----------------------------------------------------------------------
function pass:generate_pass ()
   awful.prompt.run( { prompt = "Password name: " },
      self.prompt.widget, function(s) gen_pass(self, s) end)
end
-- }}}

--- self:toggle_pass_menu -- {{{
----------------------------------------------------------------------
-- Shows or closes the pass menu
----------------------------------------------------------------------
function pass:toggle_pass_menu ()   
   if self.pass_menu == nil or self.pass_menu.visible == false then
      awful.spawn.easy_async(self.tree_cmd .. " " .. self.tree_cmd_args ..
                                " " .. self.pass_store,
                             function(s,e,exr,exc)
                                self:show_pass_menu_callback(s,e,exr,exc)
      end)
   else
      self.pass_menu.hide()
   end
end
-- }}}

-- }}}

--- Constructor
-- {{{
function pass.new(base, args)
   local homedir = "/home/" .. os.getenv("USER") .. "/"  
   local _pass          = gtable.join(base, pass)

   args = args or {}
   args.theme = args.theme or {}
   args.theme.menu = args.theme.menu or {}
   args.theme.menu.width = args.theme.menu.width or 150   

   _pass.pass_store     = homedir .. ".password-store"
   _pass.tree_cmd       = "/usr/bin/tree"
   _pass.tree_cmd_args  = "--noreport -F -i -f"
   _pass.pass_cmd       = "/usr/bin/pass"
   _pass.pass_show_args = "-c"
   _pass.pass_gen_args  = "-c"
   _pass.pass_gen_len   = 16
   _pass.pass_md5       = ""
   _pass.theme          = args.theme
   _pass.pass_menu      = nil
   _pass.prompt         = args.prompt

   _pass:buttons(gtable.join(
                    awful.button({}, 1,
                       function ()
                          _pass:toggle_pass_menu()
   end)))
   
   return _pass
end

function pass.mt:__call(...)
   return pass.new(...)
end

-- }}}

return setmetatable(pass, pass.mt)
