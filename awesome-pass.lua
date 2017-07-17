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
local lut          = require('lua-utils.table' )
local lus          = require('lua-utils.string')
local awful        = require('awful'           )
local naughty      = require('naughty'         )
local gstring      = require('gears.string'    )
local gtable       = require('gears.table'     )
local md5          = require('md5'             )

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
local function build_pass_show_func (_pass, dir, name)
   return function ()
      awful.util.spawn(_pass.pass_cmd .. " show " ..
                       _pass.pass_show_args .. " " ..
                       dir .. "/" .. name)
   end   
end

local function find_sub_menu(t, dirs)   
   local dirs = dirs

   if next(dirs) == nil then
      return t
   end
   
   local dir = table.remove(dirs, 1)
   
   for i,v in ipairs(t) do
      if v[1] == dir then
         if table.getn(dirs) == 0 then
            return v[2]
         else
            return find_sub_menu(v[2], dirs)
         end
      end
   end
   
   return nil
end

local function create_sub_menu(t, dirs)
   local dirs = dirs
   if table.getn(dirs) == 0 then
      return t
   end
   local dir = table.remove(dirs, 1)
   local submenu = find_sub_menu(t, { dir } )
   if submenu == nil then
      table.insert(t, { dir, {} })
      submenu = find_sub_menu(t, { dir })
   end
   create_sub_menu(submenu, dirs)
end

local function parse_pass_list (_pass, pass_list)
   local retval = {}
   for _, s in pairs(pass_list) do
      if string.find(s, "\.gpg$") then
         local _, _, dir, name = string.find(s, "(.*/)(.-).gpg$")
         local submenu = find_sub_menu(retval, remove_blanks(split(dir,"/")))
         table.insert(submenu, { name, build_pass_show_func (_pass, dir, name) })
      else
         create_sub_menu(retval, remove_blanks(split(s,"/")))
      end
   end

   return retval
end

local function gen_pass (_pass, pass_name)
   local retval = awful.util.spawn(_pass.pass_cmd .. " generate " ..
                                      _pass.pass_gen_args .. " " .. pass_name ..
                                      " " .. _pass.pass_gen_len)
   
   naughty.notify({title="Pass Generation", text = "Done", timeout = 10})
end
-- }}}

--- Public Methods
-- {{{

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
   return not self.pass_md5 == md5.sumhexa(pass_tree_data)
end
-- }}}

--- pass:build_pass_table -- {{{
----------------------------------------------------------------------
-- Builds a table from the entries in the password-store tree
-- @param pass_tree_data output from the `tree' call on the
--                       password-store
----------------------------------------------------------------------
function pass:build_pass_table (pass_tree_data)
   -- Split the data by lines and quote any control characters in the
   -- resulting set of strings
   local pass_list = lut.remove_blanks(lut.map(lus.lines(pass_tree_data),
                                               function (s)
                                                  return gstring.quote_pattern(s)
                                               end))
   self.pass_menu = awful.menu(
      {theme = {self.theme.menu},
       items = gtable.join(
          {{"Generate ... ", function () self:gen_password() end},
           {""}},
          parse_pass_list(self, pass_list))},
      self.widget)
end
-- }}}

--- pass:show_pass_menu -- {{{
----------------------------------------------------------------------
-- Shows the pass menu
-- @param pass_tree_data output from the `tree' call on the
--                       password-store
----------------------------------------------------------------------
function pass:show_pass_menu (pass_tree_data)
   -- check first to see if we actually need to do anything (password
   -- store has changed and the table hasn't been built yet)
   if self.pass_store_has_changed(pass_tree_data) or self.pass_menu == nil then
      self:parse_pass_tree(pass_tree_data)
   end

   self.pass_menu:toggle()
end
-- }}}

function pass:toggle_pass_menu()
   -- regenerate the menu if it doesn't exist or if it isn't visible
   if not self.pass_menu or self.pass_menu.wibox.visible == false then
      awful.spawn.easy_async(self.tree_cmd .. " " .. self.tree_cmd_args ..
                                " " .. self.pass_store,
        function (stdout, stderr, reason, exit_code)
           local pass_lines = lines(stdout)
           -- Remove the `Password Store' header
           table.remove(pass_lines,1)
           for i,v in ipairs(pass_lines) do
              print(v)
           end
           local pass_table = parse_pass_list(self,
                                              remove_blanks(lut.map(pass_lines,
                                                   function (s)
                                                      return gstring.quote_pattern(s)
                                                   end)))
           pass_table = gtable.join({{"Generate... ", function() self:generate_pass() end},
                 {""}}, pass_table)
           self.pass_menu = awful.menu({theme = {self.theme.menu},
                                        items = pass_table},
              self.widget)
           self.pass_menu:toggle()
      end)
   else
      self.pass_menu:toggle()
   end
end

function pass:generate_pass()
   awful.prompt.run( { prompt = "Password name: " },
      self.prompt.widget, function(s) gen_pass(self, s) end)
end
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

   _pass.pass_store     = homedir .. "/.password-store"
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
