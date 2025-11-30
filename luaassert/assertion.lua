local util = require("luaassert.util")
local config = require("luaassert.config")
local flag = require("luaassert.util").flag
local test = require("luaassert.util").test
local getMessage = require("luaassert.util").getMessage
local addMethod = require("luaassert.util").addMethod
local printDiffOrStringify = require("luaassert.utils.diff").printDiffOrStringify
local matcherHint = require("luaassert.matchers.matcherUtils").matcherHint
local printExpected = require("luaassert.matchers.matcherUtils").printExpected
local tableConcat = table.concat
---@namespace Luaassert


--- 处理断言结果
---@param err AssertionError
---@param diffOptions? DiffOptions
local function processError(err, diffOptions)
    if not config.throwString then
        error(err)
    end
    -- 此时我们需要将其处理为字符串形式
    local diff = ""
    if err.showDiff then
        diff = printDiffOrStringify(err.actual, err.expected, diffOptions)
    end
    local msg = {
        "\n",
        err.message,
        diff ~= "" and "\n\n" or "",
        diff,
    }
    error(tableConcat(msg))
end

---@class AssertionStatic
---@field _obj any 目标对象
local Assertion = {}

---@package
Assertion.__index = function(self, key)
    if key == "not_" then
        flag(self, "negate", true)
        return self
    end
    flag(self, "__name", key)
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
        __flags = {
            ssfi = ssfi or Assertion,
            message = msg,
            eql = config.deepEqual or util.deepCompare,
        },
    }, Assertion)

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
        processError(error_msg)
    end
end

do
    Assertion.addMethod("toBe", function(self, expected)
        local actual = self._obj
        local pass = actual == expected
        local message = pass and function()
            return matcherHint("toBe", nil, nil, {
                    isNot = flag(self, "negate"),
                }) ..
                "\n\n" ..
                "Expected: not " .. printExpected(expected)
        end or function()
            return matcherHint("toBe", nil, nil, {
                isNot = flag(self, "negate"),
            })
        end
        self:assert(
            pass,
            message,
            message,
            expected,
            actual
        )
    end)
    Assertion.new(10):toBe(11)
end

return Assertion
