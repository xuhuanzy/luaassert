local util = require("luaassert.util")
local config = require("luaassert.config")
local flag = require("luaassert.util").flag
local addMethod = require("luaassert.util").addMethod
local i18n = require("luaassert.languages.i18n")
local matcherUtils = require("luaassert.matchers.matcherUtils")
local errorLevel = require("luaassert.util").errorLevel
local RECEIVED_COLOR = matcherUtils.RECEIVED_COLOR
---@namespace Luaassert


---@class Assertion<T>: Matchers<T> & Inverse<Matchers<T>>
---@field _obj any 断言目标
local Assertion = {}

---@package
Assertion.__index = function(self, key)
    if key == "not_" then
        flag(self, "negate", true)
        return self
    end
    return rawget(Assertion, key)
end

---@param obj any 断言目标
---@param msg? string 自定义错误消息
---@param ssfi? function 起始栈函数指示器. 用于在断言失败时移除内部堆栈帧, 以提供更清晰的错误栈信息.
---@return Assertion
function Assertion.new(obj, msg, ssfi)
    ---@type Assertion
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
---@param fn (fun(self: Assertion, ...: any): ExpectationResult) 方法体
function Assertion.addMethod(name, fn)
    local function wrapAssertionMethod(self, ...)
        local result = fn(self, ...)
        local isNot = flag(self, "negate")
        if (result.pass and isNot) or (not result.pass and not isNot) then
            local message = result.message and result.message() or RECEIVED_COLOR(i18n("没有为此匹配器指定消息。"))
            error(message, errorLevel())
        end
    end

    addMethod(Assertion, name, wrapAssertionMethod)
end

return Assertion
