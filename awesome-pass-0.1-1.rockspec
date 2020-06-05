package = "awesome-pass"
version = "0.1-1"
source = {
  url = "git://github.com/thartman83/awesome-pass",
  tag = "v0.1"
}

description = {
  summary = "A pass widget for the Awesome Window Manager",
  detailed = [[
  Generate and copy passwords from a pass password store
  ]],
  homepage = "git://github.com/thartman83/awesome-pass",
  license = "GPL v2"
}

dependencies = {
  "lua >= 5.1"
}

supported_platforms = { "linux" }
build = {
  type = "builtin",
  modules = { awesome_pass = "awesome-pass.lua" }
}