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

local awful = require('awful')
local pass = {}

pass.user = awful.util.pread("whoami"):gsub("\n","")
pass.password_store_dir = "/home/" .. pass.user .. "/.password-store/"
pass.tree_cmd = "tree"
pass.tree_cmd_args = "--noreport -F -i -f"
pass.pass_cmd = "/usr/bin/pass"
pass.pass_show_args = "-c"
pass.pass_icon = ""

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
   local function helper(part) table.insert(t, part) return "" end
   helper((str:gsub("(.-)" .. delim, helper)))
   if noblanks then
      return remove_blanks(t)
   else
      return t
   end
end

local function esc(x)
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

local function generate_pass_show_func (dir, name)
   return function ()
      awful.util.spawn(pass.pass_cmd .. " show " ..
                       pass.pass_show_args .. " " ..
                       dir .. "/" .. name)
   end
end

local function parse_pass_list (pass_list)
   local retval = {}
   
   for _, s in pairs(pass_list) do
      local spot = retval
      if string.find(s, "\.gpg$") then
         _, _, dir, name = string.find(s, "(.*/)(.-).gpg$")
         if dir ~= nil then
            for _, part in pairs(remove_blanks(split(dir, "/", t))) do
               spot = spot[part]
            end
            table.insert(spot, { name, generate_pass_show_func (dir, name) } )
         else
            _, _, name = string.find(s, "(.-).gpg$")
            table.insert(retval, {name, generate_pass_show_func ("", name) } )
         end
      else
         for _, part in pairs(remove_blanks(split(s, "/", t))) do
            if spot[part] == nil then
               spot[part] = {}
            end
            spot = spot[part]
         end
      end
   end

--   print_r(retval)

   return retval
end

function pass:generate_pass_menu ()
   local pass_raw = awful.util.pread(pass.tree_cmd .. " " .. pass.tree_cmd_args ..
                                        " " .. pass.password_store_dir)
   local pass_lines = lines(pass_raw)
   table.remove(pass_lines,1)
   local clean_lines = map(function (s)
         return s:gsub(esc(pass.password_store_dir),"")
                           end,
      pass_lines)
   
   local pass_table = parse_pass_list(clean_lines)

   return awful.menu(pass_table)
end

function pass:widget()
   local w = awful.widget.button({ image = pass.pass_icon,
                                   theme = {width = 300}})
   w:buttons(awful.util.table.join(
                awful.button({ }, 1, function ()
                      -- if the menu doesn't exist create it
                      
                      -- if the menu is currently active don't regenerate
                      if not w["pass_menu"] or w.pass_menu.visible == false then
                         w.pass_menu = pass:generate_pass_menu()
                      end
                      w.pass_menu:toggle()
   end)))
   return w
end

return pass
