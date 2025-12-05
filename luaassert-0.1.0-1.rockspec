package = "luaassert"
version = "0.1.0-1"
source = {
   url = "git+https://github.com/xuhuanzy/luaassert.git"
}
description = {
   summary = "一个适用于`Lua 5.4`的断言库.",
   detailed = "一个适用于`Lua 5.4`的断言库.",
   homepage = "https://github.com/xuhuanzy/luaassert",
   license = "MIT <http://opensource.org/licenses/MIT>"
}
dependencies = {}

build = {
   type = "builtin",
   modules = {
      ["luaassert.assertion"] = "luaassert\\assertion.lua",
      ["luaassert.expect"] = "luaassert\\expect.lua",
      ["luaassert.init"] = "luaassert\\init.lua",
      ["luaassert.languages.i18n"] = "luaassert\\languages\\i18n.lua",
      ["luaassert.languages.locale"] = "luaassert\\languages\\locale.lua",
      ["luaassert.matchers.constants"] = "luaassert\\matchers\\constants.lua",
      ["luaassert.matchers.init"] = "luaassert\\matchers\\init.lua",
      ["luaassert.matchers.matcherUtils"] = "luaassert\\matchers\\matcherUtils.lua",
      ["luaassert.matchers.matchers"] = "luaassert\\matchers\\matchers.lua",
      ["luaassert.matchers.spyMatchers"] = "luaassert\\matchers\\spyMatchers.lua",
      ["luaassert.matchers.types"] = "luaassert\\matchers\\types.lua",
      ["luaassert.spy.init"] = "luaassert\\spy\\init.lua",
      ["luaassert.spy.mock"] = "luaassert\\spy\\mock.lua",
      ["luaassert.spy.types"] = "luaassert\\spy\\types.lua",
      ["luaassert.types"] = "luaassert\\types.lua",
      ["luaassert.util"] = "luaassert\\util.lua",
      ["luaassert.utils.colored"] = "luaassert\\utils\\colored.lua",
      ["luaassert.utils.diff.init"] = "luaassert\\utils\\diff\\init.lua",
      ["luaassert.utils.diff.normalizeDiffOptions"] = "luaassert\\utils\\diff\\normalizeDiffOptions.lua",
      ["luaassert.utils.diff.types"] = "luaassert\\utils\\diff\\types.lua",
      ["luaassert.utils.prettyFormat"] = "luaassert\\utils\\prettyFormat.lua",
      ["luaassert.utils.types"] = "luaassert\\utils\\types.lua"
   }
}
