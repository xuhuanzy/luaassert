local expect = require('luaassert.expect')
local setMatchers = require("luaassert.matchers").setMatchers
local matchers = require("luaassert.matchers.matchers")

setMatchers(matchers, true)

return expect
