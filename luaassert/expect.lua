local getMatchers = require("luaassert.matchers").getMatchers
local i18n = require("luaassert.languages.i18n")
local matcherUtils = require("luaassert.matchers.matcherUtils")
local errorLevel = require("luaassert.util").errorLevel
local deepCopy = require("luaassert.util").deepCopy
---@namespace Luaassert

--- 处理断言结果
---@param context MatcherContext
---@param result ExpectationResult
local function processResult(context, result)
    if (result.pass and context.isNot) or (not result.pass and not context.isNot) then
        local message = result.message and result.message() or matcherUtils.RECEIVED_COLOR(i18n("没有为此匹配器指定消息。"))
        error(message, errorLevel())
    end
end

---@class Assertion<T>: Matchers<T> & Inverse<Matchers<T>>
---@field package context MatcherContext
---@field package matcher function
local Assertion = {}

---@private
---@param self Assertion<T>
---@param key string
---@return function|nil
Assertion.__index = function(self, key)
    if key == "not_" and self.context.isNot == false then
        self.context.isNot = true
        ---@diagnostic disable-next-line: return-type-mismatch
        return self
    end
    local method = rawget(Assertion, key)
    if method then
        return method
    end
    local matcher = getMatchers()[key]
    if not matcher then
        error(i18n("expect: %s 不是有效的匹配器", key))
    end

    return function(_, ...)
        local context = deepCopy(self.context)
        self:resetState()
        local result = matcher(context, ...)
        processResult(context, result)
        return result
    end
end

---@package
--- 重置部分状态以复用断言对象
function Assertion:resetState()
    self.context.isNot = false
end

---@package
---@param actual any
---@return Assertion
function Assertion.new(actual)
    return setmetatable({
        ---@type MatcherContext
        context = {
            actual = actual,
            isNot = false,
        },
    }, Assertion)
end

---@export namespace
---@class Expect
---@overload fun<T>(actual: T): Assertion<T>
local expect = {}

local ExpectMetatable = {
    ---@param actual any
    __call = function(self, actual)
        return Assertion.new(actual)
    end,
}
setmetatable(expect, ExpectMetatable)
return expect
