local util = require("luaassert.util")
local config = require("luaassert.config")
local flag = require("luaassert.util").flag
local test = require("luaassert.util").test
local getMessage = require("luaassert.util").getMessage
local addMethod = require("luaassert.util").addMethod
---@namespace Luaassert

---@class AssertionStatic
---@field _obj any 目标对象
local Assertion = {}

---@package
Assertion.__index = function(self, key)
    if key == "not_" then
        flag(self, "negate", true)
        return self
    end
    return rawget(Assertion, key)
end

---@param obj any 目标对象
---@param msg? string 自定义错误消息
---@param ssfi? function 起始栈函数指示器. 用于在断言失败时移除内部堆栈帧, 以提供更清晰的错误栈信息.
---@return Assertion
function Assertion.new(obj, msg, ssfi)
    ---@type AssertionStatic
    local self = setmetatable({
        _obj = obj,
    }, Assertion)

    flag(self, "ssfi", ssfi or Assertion)
    flag(self, "message", msg)
    flag(self, "eql", config.deepEqual or util.deepCompare)

    return self
end

---@param name string 方法名
---@param fn fun(self: AssertionStatic, ...: any) 方法体
function Assertion.addMethod(name, fn)
    addMethod(Assertion, name, fn)
end

---@param expr any 表达式
---@param msg string | (fun(): string) 自定义错误消息
---@param negateMsg string | (fun(): string) 自定义否定错误消息
---@param expected any 预期值
---@param actual? any 实际值
---@param showDiff? boolean 是否显示差异. 如果为`true`, 则在断言失败时除了显示消息外还会显示差异.
function Assertion:assert(expr, msg, negateMsg, expected, actual, showDiff)
    local ok = test(self, expr) or false
    if not ok then
        if showDiff ~= false then
            showDiff = true
        end
        if expected == nil and actual == nil then
            showDiff = false
        end
        if config.showDiff ~= true then
            showDiff = false
        end
        msg = getMessage(self, msg, negateMsg, expected, actual)
        actual = actual or self._obj
        ---@type AssertionError
        local error_msg = {
            message = msg,
            ssf = flag(self, 'ssfi'),
            actual = actual,
            expected = expected,
            showDiff = showDiff,
        }
        error(error_msg)
    end
end

do
    Assertion.addMethod("toBe", function(self, expected)
        local actual = self._obj
        local pass = actual == expected
        self:assert(pass,
            "expected #{this} to be #{exp} // a == b",
            'expected #{this} not to be #{exp} // a == b',
            expected,
            actual
        )
    end)
    Assertion.new(9, "9 不是 10"):toBe(10)
end

return Assertion
