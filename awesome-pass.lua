
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
local awful        = require('awful')
local beautiful    = require('beautiful')
local wibox        = require('wibox')
local naughty      = require("naughty")


local pass = { mt = {} }

--- Helper functions
-- {{{
local table_update = function (t, set)
    for k, v in pairs(set) do
        t[k] = v
    end
    return t
end

local function map(func, arr)
   local retval = {}
   for i,v in ipairs(arr) do
      retval[i] = func(v)
   end
   return retval
end

local function lines(str)
   local t = {}
   local function helper(line) table.insert(t, line) return "" end
   helper((str:gsub("(.-)\r?\n", helper)))
   return t
end

local function split(str, delim, noblanks)   
   local t = {}
   if str == nil then
      return t
   end
   
   local function helper(part) table.insert(t, part) return "" end
   helper((str:gsub("(.-)" .. delim, helper)))
   if noblanks then
      return remove_blanks(t)
   else
      return t
   end
end

local function esc_string(x)
   return (x:gsub('%%', '%%%%')
              :gsub('^%^', '%%^')
              :gsub('%$$', '%%$')
              :gsub('%(', '%%(')
              :gsub('%)', '%%)')
              :gsub('%.', '%%.')
              :gsub('%[', '%%[')
              :gsub('%]', '%%]')
              :gsub('%*', '%%*')
              :gsub('%+', '%%+')
              :gsub('%-', '%%-')
              :gsub('%?', '%%?'))
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
function pass:toggle_pass_menu()
   -- regenerate the menu if it doesn't exist or if it isn't visible
   if not self.pass_menu or self.pass_menu.wibox.visible == false then
      awful.spawn.easy_async(self.tree_cmd .. " " .. self.tree_cmd_args ..
                                " " .. self.pass_store,
        function (stdout, stderr, reason, exit_code)
           local pass_lines = lines(stdout)
           -- Remove the `Password Store' header
           table.remove(pass_lines,1)
           local pass_table = parse_pass_list(self,
                                              remove_blanks(map(function (s)
                                                return s:gsub(esc_string(self.pass_store),"")
                                              end,
                                                               pass_lines)))
           pass_table = awful.util.table.join({{"Generate... ", function() self:generate_pass() end},
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
   args = args or {}
   args.theme = args.theme or {}
   args.theme.menu = args.theme.menu or {}
   args.theme.menu.width = args.theme.menu.width or 150


   local homedir = "/home/" .. os.getenv("USER") .. "/"
   local _pass = table_update(base,
                              {
                                 -- functions
                                 toggle_pass_menu = pass.toggle_pass_menu,
                                 generate_pass = pass.generate_pass,

                                 -- options
                                 pass_store = homedir .. "/.password-store",
                                 tree_cmd = "/usr/bin/tree",
                                 tree_cmd_args = "--noreport -F -i -f",
                                 pass_cmd = "/usr/bin/pass",
                                 pass_show_args = "-c",
                                 pass_gen_args = "-c",
                                 pass_gen_len = 16,

                                 -- theme
                                 theme = args.theme,

                                 -- menus                                 
                                 pass_menu = nil,

                                 -- prompt
                                 prompt = args.prompt
   })

    _pass:buttons(awful.util.table.join(
                     awful.button({}, 1,
                        function ()
                           _pass:toggle_pass_menu()
                     end)
    ))
   
   return _pass
end

function pass.mt:__call(...)
   return pass.new(...)
end

-- }}}

return setmetatable(pass, pass.mt)
