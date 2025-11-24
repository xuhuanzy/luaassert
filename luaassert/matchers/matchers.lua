local i18n = require("luaassert.languages.i18n")
local matcherHint = require("luaassert.matchers.matcherUtils").matcherHint
local deepCompare = require("luaassert.util").deepCompare
local printDiffOrStringify = require("luaassert.matchers.matcherUtils").printDiffOrStringify
local printExpected = require("luaassert.matchers.matcherUtils").printExpected
local printReceived = require("luaassert.matchers.matcherUtils").printReceived
---@namespace Luaassert

local EXPECTED_LABEL = 'Expected'; ---@readonly
local RECEIVED_LABEL = 'Received'; ---@readonly
local EXPECTED_VALUE_LABEL = 'Expected value'; ---@readonly
local RECEIVED_VALUE_LABEL = 'Received value'; ---@readonly

---@export namespace
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
            return matcherHint(matcherName, nil, nil, options) ..
                "\n\n" ..
                "Expected: not " .. printExpected(expected)
        end or function()
            return matcherHint(matcherName, nil, nil, options)
                .. "\n\n" ..
                printDiffOrStringify(expected, self.actual, EXPECTED_LABEL, RECEIVED_LABEL)
        end

        return {
            passed = pass,
            message = message,
        }
    end,
    toBeType = function(self, expectedType)
        local matcherName = "toBeType"
        ---@type MatcherHintOptions
        local options = {
            isNot = self.isNot,
        }
        local actualType = type(self.actual)
        return {
            passed = actualType == expectedType,
            message = function()
                return matcherHint(matcherName, nil, nil, options) ..
                    "\n\n" ..
                    printDiffOrStringify(expectedType, actualType, EXPECTED_LABEL, RECEIVED_LABEL)
            end,
        }
    end,
    toBeInteger = function(self)
        local matcherName = "toBeInteger"
        ---@type MatcherHintOptions
        local options = {
            isNot = self.isNot,
        }
        local pass = type(self.actual) == "number" and math.type(self.actual) == "integer"
        return {
            passed = pass,
            message = function()
                return matcherHint(matcherName, nil, '', options) ..
                    "\n\n" ..
                    "Received: " ..
                    printReceived(self.actual)
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
        local pass = deepCompare(self.actual, expected, true)
        local message = pass and function()
            return matcherHint(matcherName, nil, nil, options) ..
                "\n\n" ..
                "Expected: not " .. printExpected(expected)
        end or function()
            return matcherHint(matcherName, nil, nil, options)
                .. "\n\n" ..
                printDiffOrStringify(expected, self.actual, EXPECTED_LABEL, RECEIVED_LABEL)
        end
        return {
            passed = pass,
            message = message,
        }
    end,
}


return matchers
