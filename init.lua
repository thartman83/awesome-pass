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

--- Libraries -- {{{o
local setmetatable = setmetatable
local math         = math
local color        = require('gears.color' )
local wibox        = require('wibox'       )
local cairo        = require('lgi'         )
local pango        = require('lgi'         ).Pango
local pangocairo   = require('lgi'         ).PangoCairo
local awful        = require('awful'       )
local gtable       = require('gears.table' )
local gstring      = require('gears.string')
local beautiful    = require('beautiful'   )
local naughty      = require('naughty'     )
local dpi          = require('beautiful'   ).xresources.apply_dpi
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

--- pass:fit -- {{{
----------------------------------------------------------------------
-- Turn the desired width and height of the widget.
--
-- @param ctx Cairo context
-- @param width the hinted width
-- @param height the hinted height
-- @return the desired width and height, where width is width of 3
-- characters in the current font and size and height is the hinted
-- height passed into the function
----------------------------------------------------------------------
function pass:fit (ctx, width, height)
   return self._width, height
end
-- }}}

--- pass:draw -- {{{
----------------------------------------------------------------------
-- Draw the pass widget.
--
-- @param w the widget to draw
-- @param cr the cairo context
-- @param width width of the space to draw
-- @param height height of the space to draw
----------------------------------------------------------------------
function pass:draw (w, cr, width, height)
   cr:set_source(color(self._color or beautiful.fg_normal))

   cr.line_width = 1

   -- key eye
   cr:arc(width * .5 + .5,     height * .4,
          width * .3     ,     0,
          2 * math.pi)
   
   -- key shaft
   cr:move_to(width * .5, height * .5)
   cr:line_to(width * .5, height * .8)

   -- key teeth
   cr:line_to(width * .95, height * .8)
   cr:move_to(width * .5, height * .65)
   cr:line_to(width * .95, height * .65)
   
   cr:stroke()
end
-- }}}

--- pass:parse_pass_tree -- {{{
----------------------------------------------------------------------
-- Recursively build the password table from the list generated by
-- the `tree' call.
--
-- @param parent The current parent table
-- @param passlist The current list of pass entries to be processed
-- @param root The current root path of the parent table
-- @return a table, if there are no more entries in the pass list or
-- the current pass entry is at the wrong tree level, return the parent
-- otherwise return the tail recursion value of the next entry in the
-- passlist
----------------------------------------------------------------------
function pass:parse_pass_tree (parent, passlist, root)
   local i,v = next(passlist)
      
   -- if the next pass entry is blank return
   -- if the next pass entry is at the wrong level return
   if v == nil or root ~= v:sub(1, #root) then
      return parent
   end

   -- pop the passlist
   table.remove(passlist,1)
   
   local parts = gstring.split(v:sub(#root + 2),"/")
   
   if #parts == 1 then
      local full_pass_name = root .. "/" .. parts[1]
      table.insert(parent, { gstring.split(parts[1], "%.")[1],
                             self:build_pass_show_fn(full_pass_name:sub(#self.pass_store + 2, -5))})
   else
      local submenu = self:parse_pass_tree({}, passlist, root .. "/" .. parts[1])
      table.insert(parent, { parts[1], submenu })
   end
   
   return self:parse_pass_tree(parent, passlist, root)
end
-- }}}

--- pass:build_pass_menu -- {{{
----------------------------------------------------------------------
-- Callback function to build the pass list menu.
--
-- @param stdout the pass entry data to be processed, assumes a newline
-- seperate list of file and directory paths
-- @param stderr the error output, assumes to be none
-- @param exit_reason the exit reason from the asyncronous call (signal or exit)
-- @param exit_code the exit code from the asyncronous call
-- @return nothing
----------------------------------------------------------------------
function pass:build_pass_menu (stdout, stderr, exit_reason, exit_code)
   local gen_pass_prompt_fn =   
      function (parent, args)
         local layout = wibox.layout.align.horizontal()
         local margin = wibox.container.margin()
         margin:set_left(dpi(18))
         margin:set_widget(self.prompt)
         layout:connect_signal("mouse::enter", function ()
                                  awful.prompt.run {
                                     prompt  = 'New: ',
                                     textbox = self.prompt,
                                     exe_callback = function (pass_name)
                                        if pass_name ~= "" then
                                           self:generate_pass(pass_name)
                                        end
                                        self._menu:hide()
                                     end                                     
                                  }
                                end)

         layout:set_left(margin)
         
         local ret = { widget = layout,
                       cmd = {},
                       akey    = 'pass_generator',
         }         

         return ret
      end
   
   self._menu_tbl = {{ "Generate", { { new = gen_pass_prompt_fn } } },
                     {}}
   local passlist = gstring.lines(stdout)

   -- The first line of the tree output is the root directory
   local passroot = table.remove(passlist, 1)   
   self._menu_tbl = self:parse_pass_tree(self._menu_tbl, passlist, passroot)
   self._menu = awful.menu({items = self._menu_tbl })
   self._menu:show()
   self._menu.visible = true
end
-- }}}

--- pass:build_pass_show_fn -- {{{
----------------------------------------------------------------------
-- Return a function that calls pass show `pass-name'.
--
-- @param pass_name that name of the entry in the pass database to show
-- @return function that asyncronously calls `pass show ${pass-name}'
-- with pass_show_callback as the asyncronous callback function.
----------------------------------------------------------------------
function pass:build_pass_show_fn (pass_name)
   return function ()
      awful.spawn.easy_async(self.pass_cmd .. " show " .. self.pass_show_args ..
                          " " .. pass_name, self.pass_show_callback)
   end
end
-- }}}

--- pass_show_callback -- {{{
----------------------------------------------------------------------
-- Callback function to handle the output from a `pass show {pass-name}'
-- asyncronous call. This function displays the output in a naughty
-- popup and otherwise is a nop.
--
-- @param stdout The standard output from the `pass show {pass-name}' call
-- @param stderr The standard error from the `pass show {pass-name}' call
-- @param exitreason The exit reason (signal or exit)
-- @param exitcode The exit code from the `pass show {pass-name}' call
-- @return nothing
----------------------------------------------------------------------
function pass.pass_show_callback (stdout, stderr, exitreason, exitcode)
   naughty.notify({ text = (exitcode == 0) and stdout or stderr })
end
-- }}}

--- pass:generate_pass -- {{{
----------------------------------------------------------------------
-- Generate a new entry in the password store.
--
-- @param pass_name name of the password to generate
-- @return nothing
----------------------------------------------------------------------
function pass:generate_pass (pass_name)
   awful.spawn.easy_async(self.pass_cmd .. " generate " .. self.pass_gen_args ..
                             " " .. pass_name .. " " .. self.pass_gen_len,
                          self.pass_gen_callback)
end
-- }}}

--- pass.pass_gen_callback -- {{{
----------------------------------------------------------------------
-- Callback function to handle the output from a `pass gen
-- {pass-name}' asyncronous call. This function displays the output in
-- a naughty popup and otherwise is a noop
--
-- @param stdout The standard output from the `pass show {pass-name}' call
-- @param stderr The standard error from the `pass show {pass-name}' call
-- @param exitreason The exit reason (signal or exit)
-- @param exitcode The exit code from the `pass show {pass-name}' call
-- @return nothing
----------------------------------------------------------------------
function pass.pass_gen_callback (stdout, stderr, exitreason, exitcode)
   naughty.notify({ text = (exitcode == 0) and stdout or stderr })
end
-- }}}

--- pass_gen_callback -- {{{
----------------------------------------------------------------------
-- Callback function to handle the output from a `pass generate {pass-name}'
-- asyncronous call. This function displays the output in a naughty popup
-- and otherwise is a nop.
--
-- @param stdout The standard output from the `pass generate {pass-name}' call
-- @param stderr The standard error from the `pass generate {pass-name}' call
-- @param exitreason The exit reason (signal or exit)
-- @param exitcode The exit code from the `pass generate {pass-name}' call
-- @return nothing
----------------------------------------------------------------------
function pass.pass_gen_callback (stdout, stderr, exitreason, exitcode)
   naughty.notify({ text = (exitcode == 0) and stdout or stderr })
end
-- }}}

--- pass:toggle_menu -- {{{
----------------------------------------------------------------------
-- Show or close the pass menu.
--
-- @return nothing
----------------------------------------------------------------------
function pass:toggle_menu ()
   if self._menu ~= nil and self._menu.visible then
      self._menu:hide()
      self._menu.visible = false
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
-- Build a new pass widget.
--
-- @param args list of arguments to the pass widget
-- * pass_store: Location of the password store, default is ~/.password-store
-- * tree_cmd: tree executable location, default is /usr/bin/tree
-- * tree_cmd_args: arguments for tree_cmd, default is `--noreport -F -i -f'
-- * pass_cmd: pass executable location, default is /usr/bin/pass
-- * pass_show_args: arguments for `pass show' command, default is '-c'
-- * pass_gen_args: arguments for `pass generate' command, default is '16 -c'
-- @return an awesome-pass widget
----------------------------------------------------------------------
local function new (args)
   local obj = wibox.widget.base.empty_widget()
   gtable.crush(obj, pass, true)

   local args = args or {}

   obj.pass_store     = args.pass_store    or "/home/" .. os.getenv("USER") ..
                                              "/.password-store"
   obj.tree_cmd       = args.tree_cmd      or "/usr/bin/tree"
   obj.tree_cmd_args  = args.tree_cmd_args or "--noreport -F -i -f"
   obj.pass_cmd       = args.pass_cmd      or "/usr/bin/pass"
   obj.pass_show_args = args.pass_gen_args or "-c"
   obj.pass_gen_args  = args.pass_gen_args or "-c"
   obj.pass_gen_len   = args.pass_gen_len  or 16
   obj.prompt         = wibox.widget.textbox("New: ")

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
