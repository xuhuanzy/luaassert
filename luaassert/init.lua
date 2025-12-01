---@namespace Luaassert

local expect = require('luaassert.expect')
-- 侧效: 注册基础匹配器到 Assertion
require("luaassert.matchers.matchers")
local spyMatchers = require("luaassert.matchers.spyMatchers")
local mock = require("luaassert.spy.mock")

local Api = {
    expect = expect,
    mock = mock,
}

return Api
