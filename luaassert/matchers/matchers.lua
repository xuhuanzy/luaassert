local i18n = require("luaassert.languages.i18n")
local matcherUtils = require("luaassert.matchers.matcherUtils")
local matcherHint = matcherUtils.matcherHint
local deepCompare = require("luaassert.util").deepCompare
local printDiffOrStringify = matcherUtils.printDiffOrStringify
local printExpected = matcherUtils.printExpected
local printReceived = matcherUtils.printReceived
local ensureNoExpected = matcherUtils.ensureNoExpected
local ensureNumbers = matcherUtils.ensureNumbers
local hasToString = require("luaassert.util").hasToString
local printWithType = matcherUtils.printWithType
local matcherErrorMessage = matcherUtils.matcherErrorMessage
---@namespace Luaassert

local EXPECTED_LABEL = 'Expected'; ---@readonly
local RECEIVED_LABEL = 'Received'; ---@readonly

---@export namespace
---@type MatchersObject
local matchers = {
    -- 基本相等匹配器, 使用` == `进行比较
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
    -- 检查实际值的类型是否与预期值相等
    toBeType = function(self, expected)
        local matcherName = "toBeType"
        ---@type MatcherHintOptions
        local options = {
            isNot = self.isNot,
        }
        local actualType = type(self.actual)
        return {
            passed = actualType == expected,
            message = function()
                return matcherHint(matcherName, nil, nil, options) ..
                    "\n\n" ..
                    printDiffOrStringify(expected, actualType, EXPECTED_LABEL, RECEIVED_LABEL)
            end,
        }
    end,
    -- 检查实际值是否为整数
    toBeInteger = function(self, expected)
        local matcherName = "toBeInteger"
        ---@type MatcherHintOptions
        local options = {
            isNot = self.isNot,
        }
        ensureNoExpected(expected, matcherName, options)
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
    -- 深度比较实际值与预期值是否相等
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
    -- 检查实际值是否为假值
    toBeFalsy = function(self, expected)
        local matcherName = "toBeFalsy"
        ---@type MatcherHintOptions
        local options = {
            isNot = self.isNot,
        }

        ensureNoExpected(expected, matcherName, options)

        local pass = not self.actual
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
    toBeTruthy = function(self, expected)
        local matcherName = "toBeTruthy"
        ---@type MatcherHintOptions
        local options = {
            isNot = self.isNot,
        }

        ensureNoExpected(expected, matcherName, options)

        local pass = not not self.actual
        return {
            passed = pass,
            message = function()
                return matcherHint(matcherName, nil, '', options)
                    .. "\n\n"
                    .. "Received: "
                    .. printReceived(self.actual)
            end,
        }
    end,
    toThrowError = function(self, expected)
        local matcherName = "toThrowError"
        ---@type MatcherHintOptions
        local options = {
            isNot = self.isNot,
        }

        if type(self.actual) ~= "function" then
            error(matcherErrorMessage(
                matcherHint(matcherName, nil, 'expected', options),
                matcherUtils.RECEIVED_COLOR("received") .. " " .. i18n("值必须是函数"),
                printWithType('Received', self.actual, printReceived)
            ))
        end

        local ok, error_message = pcall(self.actual)
        local pass = not ok
        if hasToString(error_message) then
            error_message = tostring(error_message)
            error_message = error_message:gsub('^.-:%d+: ', '', 1)
        end
        local expectedType = type(expected)
        if expectedType == "string" then
            pass = pass and error_message == expected
        elseif expectedType == "table" then
            if type(error_message) == "table" then
                pass = pass and deepCompare(error_message, expected, true)
            else
                pass = pass and error_message == expected
            end
        else
            pass = false
        end

        local message = function()
            return matcherHint(matcherName, nil, nil, options)
                .. "\n\n" ..
                printDiffOrStringify(expected, error_message, "Expected message", "Received message")
        end

        return {
            passed = pass,
            message = message,
        }
    end,
    ---@param expected string 模式字符串
    ---@param plain? boolean 是否使用字面量匹配
    toMatch = function(self, expected, plain)
        local matcherName = "toMatch"
        ---@type MatcherHintOptions
        local options = {
            isNot = self.isNot,
        }

        if type(self.actual) ~= "string" then
            error(matcherErrorMessage(
                matcherHint(matcherName, nil, nil, options),
                matcherUtils.RECEIVED_COLOR("received") .. " " .. i18n("值必须是字符串"),
                printWithType('Received', self.actual, printReceived)
            ))
        end

        if type(expected) ~= "string" then
            error(matcherErrorMessage(
                matcherHint(matcherName, nil, nil, options),
                matcherUtils.RECEIVED_COLOR("received") .. " " .. i18n("值必须是字符串"),
                printWithType('Expected', expected, printExpected)
            ))
        end

        if plain ~= nil then
            options.secondArgument = 'plain'
        end

        local startIndex = string.find(self.actual, expected, 1, plain)

        local pass = startIndex ~= nil
        local message = function()
            local tag = "pattern: "
            if plain then
                tag = "string: "
            end

            local expectedLine = "Expected " .. tag .. printExpected(expected)
            local receivedLine = "Received string: " .. printReceived(self.actual)
            return matcherHint(matcherName, nil, nil, options) .. "\n\n" .. expectedLine .. "\n" .. receivedLine
        end

        return {
            passed = pass,
            message = message,
        }
    end,
    -- 检查实际值是否大于预期值
    toBeGreaterThan = function(self, expected)
        local matcherName = "toBeGreaterThan"
        ---@type MatcherHintOptions
        local options = {
            isNot = self.isNot,
        }

        ensureNumbers(self.actual, expected, matcherName, options)

        local pass = self.actual > expected
        local message = function()
            local expectedLine = string.format("Expected:%s > %s", options.isNot and " not" or "",
                printExpected(expected))
            local receivedLine = string.format("Received:%s   %s", options.isNot and "    " or "",
                printReceived(self.actual))
            return matcherHint(matcherName, nil, nil, options)
                .. "\n\n"
                .. expectedLine
                .. "\n"
                .. receivedLine
        end

        return {
            passed = pass,
            message = message,
        }
    end,
    -- 检查实际值是否大于或等于预期值
    toBeGreaterThanOrEqual = function(self, expected)
        local matcherName = "toBeGreaterThanOrEqual"
        ---@type MatcherHintOptions
        local options = {
            isNot = self.isNot,
        }

        ensureNumbers(self.actual, expected, matcherName, options)

        local pass = self.actual >= expected
        local message = function()
            local expectedLine = string.format("Expected:%s >= %s", options.isNot and " not" or "",
                printExpected(expected))
            local receivedLine = string.format("Received:%s    %s", options.isNot and "    " or "",
                printReceived(self.actual))
            return matcherHint(matcherName, nil, nil, options)
                .. "\n\n"
                .. expectedLine
                .. "\n"
                .. receivedLine
        end

        return {
            passed = pass,
            message = message,
        }
    end,
    -- 检查实际值是否小于预期值
    toBeLessThan = function(self, expected)
        local matcherName = "toBeLessThan"
        ---@type MatcherHintOptions
        local options = {
            isNot = self.isNot,
        }

        ensureNumbers(self.actual, expected, matcherName, options)

        local pass = self.actual < expected
        local message = function()
            local expectedLine = string.format("Expected:%s < %s", options.isNot and " not" or "",
                printExpected(expected))
            local receivedLine = string.format("Received:%s   %s", options.isNot and "    " or "",
                printReceived(self.actual))
            return matcherHint(matcherName, nil, nil, options)
                .. "\n\n"
                .. expectedLine
                .. "\n"
                .. receivedLine
        end

        return {
            passed = pass,
            message = message,
        }
    end,
    -- 检查实际值是否小于或等于预期值
    toBeLessThanOrEqual = function(self, expected)
        local matcherName = "toBeLessThanOrEqual"
        ---@type MatcherHintOptions
        local options = {
            isNot = self.isNot,
        }

        ensureNumbers(self.actual, expected, matcherName, options)

        local pass = self.actual <= expected
        local message = function()
            local expectedLine = string.format("Expected:%s <= %s", options.isNot and " not" or "",
                printExpected(expected))
            local receivedLine = string.format("Received:%s    %s", options.isNot and "    " or "",
                printReceived(self.actual))
            return matcherHint(matcherName, nil, nil, options)
                .. "\n\n"
                .. expectedLine
                .. "\n"
                .. receivedLine
        end

        return {
            passed = pass,
            message = message,
        }
    end,
}


return matchers
