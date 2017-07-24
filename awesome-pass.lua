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

--- pass:parse_pass_list -- {{{
----------------------------------------------------------------------
-- Returns a formated table of entries in the password store with each
-- entry having an associated function that to pass show -c $ENTRY
--
-- @param pass_tree_data output from the `tree' call on the
--                       password-store
----------------------------------------------------------------------
function pass:parse_pass_list (pass_tree_data)
   local menu_tbl = {}
   local menu_ctx = radical.context{}

   print(pass_tree_data)
   for s in pass_tree_data:lines() do
      
   end

   return retval
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
function pass:build_pass_table (pass_tree_data)
   self.pass_menu = radical.context{style=radical.style.classic,
                                    item_style=radical.item.style.classic}
   self.pass_menu:add_item{text="New ..."}
--   self.pass_menu = awful.menu(
--      {theme = {self.theme.menu},
--       items = gtable.join(
--          {{"Generate ... ", function () self:gen_password() end},
--           {""}},
--          self:parse_pass_list(pass_tree_data))},
--      self.widget)
end
-- }}}

--- pass:show_pass_menu_callback -- {{{
----------------------------------------------------------------------
-- 
----------------------------------------------------------------------
function pass:show_pass_menu (stdout, stderr, exitreason, exitcode)
   if exitcode ~= 0 then
      return
   end
   
   self:build_pass_table(stdout)
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
                          _pass.toggle_pass_menu()
                          awful.spawn.easy_async(_pass.tree_cmd .. " " .. _pass.tree_cmd_args ..
                                                    " " .. _pass.pass_store,
                             function(s,e,exr,exc)
                                _pass:show_pass_menu(s,e,exr,exc)
                          end)
                       end)))
   
   return _pass
end

function pass.mt:__call(...)
   return pass.new(...)
end

-- }}}

return setmetatable(pass, pass.mt)
