---@namespace Luaassert

local expect = require('luaassert.expect')
local setMatchers = require("luaassert.matchers").setMatchers
local matchers = require("luaassert.matchers.matchers")

setMatchers(matchers, true)

local Api = {
    expect = expect,

    --- 设置自定义匹配器
    ---@param matchers Luaassert.MatchersObject 自定义匹配器对象
    setMatchers = function(matchers)
        setMatchers(matchers, false)
    end,
}

return Api
