-------------------------------------------------------------------------------
-- awful.lua for awesome-pass                                                --
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
-- Awful mocks for awesome-pass testing
-- }}}

local setmetatable = setmetatable

--- awful -- {{{

--- menu mocks and stubs-- {{{
local menu    = {}
menu.mt       = {}

--- menu_call -- {{{
----------------------------------------------------------------------
-- 
----------------------------------------------------------------------
function menu_call (_, args, parent)
   return args
end
-- }}}

-- }}}
--- spawn mocks and stubs -- {{{
local spawn    = {}
spawn.callback_values = { stdout     = "",
                          stderr     = "",
                          exitreason = "",
                          exitcode   = "",
}
spawn.mt       = {}

--- spawn_call -- {{{
----------------------------------------------------------------------
--  stub for awful.spawn(...), basically a noop
----------------------------------------------------------------------
function spawn_call (...)
   return -1
end
-- }}}

--- spawn.easy_async -- {{{
----------------------------------------------------------------------
-- Mock function for spawn.easy_async
-- Instead of actually making the call to command, this mock applies
-- the values of awful.spawn.callback_values to callback
-- @param cmd (string or table) The command
-- @param callback Function with the following arguments
----------------------------------------------------------------------
function spawn.easy_async (cmd, callback)
   callback(spawn.callback_values.stdout,
            spawn.callback_values.stderr,
            spawn.callback_values.exitreason,
            spawn.callback_values.exitcode)
end
-- }}}

--- spawn.set_callback_values -- {{{
----------------------------------------------------------------------
-- Sets the global callback to be used if easy_async is invoked
----------------------------------------------------------------------
function spawn.set_callback_values (stdout, stderr, exitreason,
                                    exitcode)
   spawn.callback_values = { stdout     = stdout,
                             stderr     = stderr,
                             exitreason = exitreason,
                             exitcode   = exitcode,
   }
end
-- }}}

spawn.mt.__call = spawn_call
-- }}}
--- button mocks and stubs -- {{{
local button = {}
button.mt = {}

--- button_call -- {{{
----------------------------------------------------------------------
-- Stub for awful.button, functionally a nop
----------------------------------------------------------------------
function button_call (...)   
end
-- }}}

button.mt.__call = button_call
-- }}}

return { menu  = setmetatable(menu, {__call = menu_call}),
         spawn = setmetatable(spawn, spawn.mt),
         button = setmetatable(button, button.mt),
}
-- }}}
