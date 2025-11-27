---@namespace Luaassert

local expect = require('luaassert.expect')
local setMatchers = require("luaassert.matchers").setMatchers
local matchers = require("luaassert.matchers.matchers")
local spyMatchers = require("luaassert.matchers.spyMatchers")
local mock = require("luaassert.spy.mock")

--- 设置内部匹配器
setMatchers(matchers, true)
setMatchers(spyMatchers, true)

local Api = {
    expect = expect,
    mock = mock,

    --- 设置自定义匹配器
    ---@param matchers Luaassert.MatchersObject 自定义匹配器对象
    extend = function(matchers)
        setMatchers(matchers, false)
    end,
}

return Api
