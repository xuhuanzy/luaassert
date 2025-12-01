local i18n = require("luaassert.languages.i18n")
local isMockFunction = require("luaassert.spy.mock").isMockFunction
local matcherUtils = require("luaassert.matchers.matcherUtils")
local matcherErrorMessage = require("luaassert.matchers.matcherUtils").matcherErrorMessage
local matcherHint = require("luaassert.matchers.matcherUtils").matcherHint
local printWithType = require("luaassert.matchers.matcherUtils").printWithType
local printExpected = require("luaassert.matchers.matcherUtils").printExpected
local printReceived = require("luaassert.matchers.matcherUtils").printReceived
local ensureNoExpected = require("luaassert.matchers.matcherUtils").ensureNoExpected
local ensureExpectedIsNonNegativeInteger = require("luaassert.matchers.matcherUtils").ensureExpectedIsNonNegativeInteger
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
local NO_CALLS = i18n("mock 函数尚未被调用") ---@readonly 未调用提示

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
---@alias IndexedCall {[1]: integer, [2]: any[]}

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

---@param indexedCalls IndexedCall[]
---@param expected any[]?
---@param indent string?
---@return string
local function formatIndexedCallLines(indexedCalls, expected, indent)
    indexedCalls = indexedCalls or {}
    indent = indent or ""
    local lines = {}
    for index = 1, #indexedCalls do
        local callIndex = indexedCalls[index][1]
        local callArgs = indexedCalls[index][2] or {}
        lines[#lines + 1] = stringFormat("%s%d: %s", indent, callIndex, printReceivedArgs(callArgs, expected))
    end
    return tableConcat(lines, "\n")
end

---@param expected any[]?
---@param indexedCalls IndexedCall[]
---@param isSingleCall boolean
---@return string
local function printReceivedCallsNegative(expected, indexedCalls, isSingleCall)
    if not indexedCalls or #indexedCalls == 0 then
        return ""
    end

    if isSingleCall then
        local args = indexedCalls[1][2] or {}
        return "Received call: " .. printReceivedArgs(args, expected)
    end

    return "Received calls:\n" .. formatIndexedCallLines(indexedCalls, expected, "  ")
end

---@param expected any[]?
---@param indexedCalls IndexedCall[]
---@param expand boolean
---@param isSingleCall boolean
---@return string
local function printExpectedReceivedCallsPositive(expected, indexedCalls, expand, isSingleCall)
    local labelPrinter = matcherUtils.getLabelPrinter("Expected", "Received")
    local lines = {}
    ---@diagnostic disable-next-line: param-type-mismatch
    lines[#lines + 1] = labelPrinter("Expected") .. printExpectedArgs(expected)

    if not indexedCalls or #indexedCalls == 0 then
        lines[#lines + 1] = labelPrinter("Received") .. printReceived(NO_CALLS)
        return tableConcat(lines, "\n")
    end

    if isSingleCall or not expand then
        local args = indexedCalls[1][2] or {}
        lines[#lines + 1] = labelPrinter("Received") .. printReceivedArgs(args, expected)
    else
        lines[#lines + 1] = labelPrinter("Received") .. "\n" .. formatIndexedCallLines(indexedCalls, expected, "  ")
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
    local calls = spy.mock.calls
    local callCount = #calls
    local pass = callCount > 0

    local message ---@type fun(): string
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

---@param expected integer
Assertion.addMethod("toHaveBeenCalledTimes", function(self, expected)
    local matcherName = "toHaveBeenCalledTimes"
    local expectedArgument = "expected"
    local actual = self._obj
    ---@type MatcherHintOptions
    local options = {
        isNot = flag(self, "negate"),
    }
    ensureExpectedIsNonNegativeInteger(expected, matcherName, options)
    local spy = getSpy(actual, matcherName, expectedArgument, options)
    local mockName = spy:getMockName()
    local callCount = #spy.mock.calls
    local pass = callCount == expected
    local message
    if pass then
        message = function()
            return matcherHint(matcherName, mockName, expectedArgument, options)
                .. "\n\n"
                .. "Expected number of calls: not " .. printExpected(expected)
        end
    else
        message = function()
            return matcherHint(matcherName, mockName, expectedArgument, options)
                .. "\n\n"
                .. "Expected number of calls: " .. printExpected(expected) .. "\n"
                .. "Received number of calls: " .. printReceived(callCount)
        end
    end

    return {
        pass = pass,
        message = message,
    }
end)

Assertion.addMethod("toHaveBeenCalledWith", function(self, ...)
    local matcherName = "toHaveBeenCalledWith"
    local expectedArgument = "...expected"
    local actual = self._obj
    local expected = { ... }
    ---@type MatcherHintOptions
    local options = {
        isNot = flag(self, "negate"),
    }

    local spy = getSpy(actual, matcherName, expectedArgument, options)
    local mockName = spy:getMockName()
    local calls = spy.mock.calls or {}
    local callCount = #calls
    local pass = false

    for index = 1, callCount do
        if isEqualCall(expected, calls[index]) then
            pass = true
            break
        end
    end

    local message ---@type fun(): string
    if pass then
        message = function()
            local indexedCalls = {}
            local callIndex = 1
            while callIndex <= callCount and #indexedCalls < PRINT_LIMIT do
                if isEqualCall(expected, calls[callIndex]) then
                    indexedCalls[#indexedCalls + 1] = { callIndex, calls[callIndex] }
                end
                callIndex = callIndex + 1
            end

            local shouldSkipDetails = callCount == 1 and stringify(calls[1]) == stringify(expected)
            local result = matcherHint(matcherName, mockName, expectedArgument, options)
                .. "\n\n"
                .. "Expected: not " .. printExpectedArgs(expected) .. "\n"

            if not shouldSkipDetails then
                result = result
                    .. printReceivedCallsNegative(expected, indexedCalls, callCount == 1)
                    .. "\n"
            end

            result = result .. "Number of calls: " .. printReceived(callCount)
            return result
        end
    else
        message = function()
            local indexedCalls = {}
            local limit = mathMin(callCount, PRINT_LIMIT)
            for index = 1, limit do
                indexedCalls[#indexedCalls + 1] = { index, calls[index] }
            end

            return matcherHint(matcherName, mockName, expectedArgument, options)
                .. "\n\n"
                .. printExpectedReceivedCallsPositive(expected, indexedCalls, isExpand(flag(self, "expand")),
                    callCount == 1)
                .. "\nNumber of calls: " .. printReceived(callCount)
        end
    end

    return {
        pass = pass,
        message = message,
    }
end)
