---@namespace Luaassert

local expect = require('luaassert.expect')
require("luaassert.matchers.matchers")
require("luaassert.matchers.spyMatchers")
local mock = require("luaassert.spy.mock")

local Api = {
    expect = expect,
    mock = mock,
}

return Api
