local i18n = require("luaassert.languages.i18n")
local matcherHint = require("luaassert.matchers.matcherUtils").matcherHint
---@namespace Luaassert

---@type MatchersObject
local matchers = {
    toBe = function(self, expected)
        local matcherName = "toBe"
        ---@type MatcherHintOptions
        local options = {
            comment = "a == b",
            isNegate = self.isNegate,
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
}


return matchers
