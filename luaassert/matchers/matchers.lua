local i18n = require("luaassert.languages.i18n")
local matcherHint = require("luaassert.matchers.matcherUtils").matcherHint
local deepCompare = require("luaassert.util").deepCompare
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
    toEqual = function(self, expected)
        local matcherName = "toEqual"
        ---@type MatcherHintOptions
        local options = {
            comment = i18n("深度比较"),
            isNegate = self.isNegate,
        }
        local pass, crumbs = deepCompare(self.actual, expected)
        local message = pass and function()
            return matcherHint(matcherName, nil, nil, options)
        end or function()
            if self.isNegate then
                return matcherHint(matcherName, nil, nil, options)
            end
            return require("luaassert.matchers.matcherUtils").formatDiffMessage(matcherName, self.actual, expected,
                crumbs, options)
        end
        -- 传递一些实际值和期望值, 用于生成错误消息
        return {
            passed = pass,
            message = message,
            actual = self.actual,
            expected = expected,
            name = matcherName,
        }
    end,
}


return matchers
