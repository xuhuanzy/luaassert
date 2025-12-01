local i18n = require("luaassert.languages.i18n")
local isMockFunction = require("luaassert.spy.mock").isMockFunction
local matcherUtils = require("luaassert.matchers.matcherUtils")
local matcherErrorMessage = require("luaassert.matchers.matcherUtils").matcherErrorMessage
local matcherHint = require("luaassert.matchers.matcherUtils").matcherHint
local printWithType = require("luaassert.matchers.matcherUtils").printWithType
local printExpected = require("luaassert.matchers.matcherUtils").printExpected
local printReceived = require("luaassert.matchers.matcherUtils").printReceived
local ensureNoExpected = require("luaassert.matchers.matcherUtils").ensureNoExpected
local deepCompare = require("luaassert.util").deepCompare
local stringify = require("luaassert.matchers.matcherUtils").stringify
local Assertion = require("luaassert.assertion")
local flag = require("luaassert.util").flag
local stringFormat = string.format
local tableConcat = table.concat
local mathMin = math.min
local DIM_COLOR = matcherUtils.DIM_COLOR

---@namespace Luaassert

local PRINT_LIMIT = 3 ---@readonly 打印参数数量限制
local NO_ARGUMENTS = i18n("调用时未提供参数") ---@readonly 无参数提示

---@param expand boolean?
---@return boolean
local function isExpand(expand)
    return expand ~= false
end

---@param val any
---@return string
local function printCommon(val)
    return DIM_COLOR(stringify(val))
end

---@param expected any
---@param received any
---@return boolean
local function isEqualValue(expected, received)
    return deepCompare(expected, received, true)
end

---@param expected any[]
---@return string
local function printExpectedArgs(expected)
    expected = expected or {}
    if #expected == 0 then
        return NO_ARGUMENTS
    end

    local printed = {}
    for index = 1, #expected do
        printed[index] = printExpected(expected[index])
    end
    return tableConcat(printed, ", ")
end


---@param expected any[]
---@param received any[]
---@return boolean
local function isEqualCall(expected, received)
    expected = expected or {}
    received = received or {}
    if #received ~= #expected then
        return false
    end
    return isEqualValue(expected, received)
end

---@param expected any
---@param result table
---@return boolean
local function isEqualReturn(expected, result)
    return result ~= nil and result.type == "return" and isEqualValue(expected, result.value)
end

---@param results table[]
---@return integer
local function countReturns(results)
    results = results or {}
    local total = 0
    for index = 1, #results do
        if results[index] and results[index].type == "return" then
            total = total + 1
        end
    end
    return total
end

---@param returnCount integer
---@param callCount integer
---@return string
local function printNumberOfReturns(returnCount, callCount)
    local message = "\nNumber of returns: " .. printReceived(returnCount)
    if callCount ~= returnCount then
        message = message .. "\nNumber of calls:   " .. printReceived(callCount)
    end
    return message
end

---@alias PrintLabel fun(text: string, isExpectedCall: boolean): string

---@param received any
---@param matcherName string
---@param expectedArgument any
---@param options MatcherHintOptions
---@return Mock
local function getSpy(received, matcherName, expectedArgument, options)
    if not isMockFunction(received) then
        error(matcherErrorMessage(
            matcherHint(matcherName, nil, expectedArgument, options),
            matcherUtils.RECEIVED_COLOR("received") .. " " .. i18n("值必须是 mock 或 spy 函数"),
            printWithType('Received', received, printReceived)
        ))
    end
    return received
end


---@param received any[]
---@param expected any[]?
---@return string
local function printReceivedArgs(received, expected)
    received = received or {}
    if #received == 0 then
        return NO_ARGUMENTS
    end

    local printed = {}
    for index = 1, #received do
        local value = received[index]
        if expected and index <= #expected and isEqualValue(expected[index], value) then
            printed[index] = printCommon(value)
        else
            printed[index] = printReceived(value)
        end
    end

    return tableConcat(printed, ", ")
end

---@param calls any[][]
---@return string
local function formatCallLines(calls)
    calls = calls or {}
    local count = #calls
    local limit = mathMin(count, PRINT_LIMIT)
    local lines = {}
    for index = 1, limit do
        local callArgs = calls[index] or {}
        lines[#lines + 1] = stringFormat("%d: %s", index, printReceivedArgs(callArgs))
    end
    return tableConcat(lines, "\n")
end

Assertion.addMethod("toHaveBeenCalled", function(self, ...)
    local actual = self._obj
    ---@type MatcherHintOptions
    local options = {
        isNot = flag(self, "negate"),
    }
    local spy = getSpy(actual, "toHaveBeenCalled", "", options)
    local mockName = spy:getMockName()
    local calls = (spy.mock and spy.mock.calls) or {}
    local callCount = #calls
    local pass = callCount > 0

    local message
    if pass then
        message = function()
            return matcherHint("toHaveBeenCalled", mockName, "", options)
                .. "\n\n"
                .. "Expected number of calls: " .. printExpected(0) .. "\n"
                .. "Received number of calls: " .. printReceived(callCount) .. "\n\n"
                .. formatCallLines(calls)
        end
    else
        message = function()
            return matcherHint("toHaveBeenCalled", mockName, "", options)
                .. "\n\n"
                .. "Expected number of calls: >= " .. printExpected(1) .. "\n"
                .. "Received number of calls:    " .. printReceived(callCount)
        end
    end

    return {
        pass = pass,
        message = message,
    }
end)
