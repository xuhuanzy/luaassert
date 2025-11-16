local i18n = require("luaassert.languages.i18n")
local matcherHint = require("luaassert.matchers.matcherUtils").matcherHint
local deepCompare = require("luaassert.util").deepCompare
local printDiffOrStringify = require("luaassert.matchers.matcherUtils").printDiffOrStringify
local printExpected = require("luaassert.matchers.matcherUtils").printExpected
---@namespace Luaassert

local EXPECTED_LABEL = 'Expected'; ---@readonly
local RECEIVED_LABEL = 'Received'; ---@readonly
local EXPECTED_VALUE_LABEL = 'Expected value'; ---@readonly
local RECEIVED_VALUE_LABEL = 'Received value'; ---@readonly

---@type MatchersObject
local matchers = {
    toBe = function(self, expected)
        local matcherName = "toBe"
        ---@type MatcherHintOptions
        local options = {
            comment = "a == b",
            isNot = self.isNot,
        }

        local pass = self.actual == expected
        local message = pass and function()
            return matcherHint(matcherName, nil, nil, options)
        end or function()
            return matcherHint(matcherName, nil, nil, options)
        end

        return {
            passed = pass,
            message = message,
        }
    end,
    toBeType = function(self, expectedType)
        return {
            passed = type(self.actual) == expectedType,
            message = function()
                return i18n("expect: 期望 %s 类型为 %s", self.actual, expectedType)
            end,
        }
    end,
    toBeInteger = function(self)
        return {
            passed = type(self.actual) == "number" and math.type(self.actual) == "integer",
            message = function()
                return i18n("expect: 期望 %s 为整数", self.actual)
            end,
        }
    end,
    toEqual = function(self, expected)
        local matcherName = "toEqual"
        ---@type MatcherHintOptions
        local options = {
            comment = i18n("深度比较"),
            isNot = self.isNot,
        }
        local pass = deepCompare(self.actual, expected)
        local message = pass and function()
            return matcherHint(matcherName, nil, nil, options) ..
                "\n\n" ..
                "Expected: not " .. printExpected(expected)
        end or function()
            return matcherHint(matcherName, nil, nil, options)
                .. "\n\n" ..
                printDiffOrStringify(expected, self.actual, EXPECTED_LABEL, RECEIVED_LABEL)
        end
        -- 传递一些实际值和期望值, 用于生成错误消息
        return {
            passed = pass,
            message = message,
        }
    end,
}


return matchers
