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

function print_r ( t )  
    local print_r_cache={}
    local function sub_print_r(t,indent)
        if (print_r_cache[tostring(t)]) then
            print(indent.."*"..tostring(t))
        else
            print_r_cache[tostring(t)]=true
            if (type(t)=="table") then
                for pos,val in pairs(t) do
                    if (type(val)=="table") then
                        print(indent.."["..pos.."] => "..tostring(t).." {")
                        sub_print_r(val,indent..string.rep(" ",string.len(pos)+8))
                        print(indent..string.rep(" ",string.len(pos)+6).."}")
                    elseif (type(val)=="string") then
                        print(indent.."["..pos..'] => "'..val..'"')
                    else
                        print(indent.."["..pos.."] => "..tostring(val))
                    end
                end
            else
                print(indent..tostring(t))
            end
        end
    end
    if (type(t)=="table") then
        print(tostring(t).." {")
        sub_print_r(t,"  ")
        print("}")
    else
        sub_print_r(t,"  ")
    end
    print()
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

local function parse_pass_list (pass_list)
   local retval = {}
   for _, s in pairs(pass_list) do
      if string.find(s, "\.gpg$") then
         local _, _, dir, name = string.find(s, "(.*/)(.-).gpg$")
         local submenu = find_sub_menu(retval, remove_blanks(split(dir,"/")))
         table.insert(submenu, { name, generate_pass_show_func (dir, name) })
      else
         create_sub_menu(retval, remove_blanks(split(s,"/")))
      end
   end

   return retval
end

function pass:generate_pass_menu ()
   local pass_raw = awful.util.pread(pass.tree_cmd .. " " .. pass.tree_cmd_args ..
                                        " " .. pass.password_store_dir)
   local pass_lines = lines(pass_raw)
   table.remove(pass_lines,1)
   local pass_table =
      parse_pass_list(remove_blanks(map(function (s)
                                      return s:gsub(esc(pass.password_store_dir),"")
                                        end,
                                       pass_lines)))
   return awful.menu({
         theme = { width = 150, },
         items = pass_table})
end

function pass:widget()
   local w = awful.widget.button({ image = pass.pass_icon, })
   w:buttons(awful.util.table.join(
                awful.button({ }, 1, function ()
                      -- if the menu is currently active don't regenerate
                      if not w["pass_menu"] or w.pass_menu.wibox.visible == false then
                         w.pass_menu = pass:generate_pass_menu()
                      end
                      w.pass_menu:toggle()
   end)))
   return w
end

return pass
