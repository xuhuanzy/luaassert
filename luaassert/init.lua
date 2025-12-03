---@namespace Luaassert

local expect = require('luaassert.expect')
require("luaassert.matchers.matchers")
require("luaassert.matchers.spyMatchers")
local Assertion = require("luaassert.assertion")
local mock = require("luaassert.spy.mock")
local util = require("luaassert.util")

---@type table<function, true>
local used = {}

-- 注册自定义断言函数
---@param fn fun(exports: table, util: table)
---@return table @ 导出表
local function use(fn)
    local exports = {
        Assertion = Assertion,
        util = util,
    }
    if not used[fn] then
        fn(exports, util)
        used[fn] = true
    end

    return exports
end

local Api = {
    expect = expect,
    mock = mock,
    use = use,
}

return Api
