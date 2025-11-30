---@namespace Luaassert

local stringFormat = string.format
local deepCompare = require("luaassert.util").deepCompare
local colored = require('luaassert.utils.colored')
local i18n = require("luaassert.languages.i18n")
local normalizeDiffOptions = require("luaassert.utils.diff.normalizeDiffOptions")
local getLabelPrinter = require("luaassert.matchers.matcherUtils").getLabelPrinter
local printExpected = require("luaassert.matchers.matcherUtils").printExpected
local printReceived = require("luaassert.matchers.matcherUtils").printReceived
local prettyFormat = require("luaassert.utils.prettyFormat").format
local tostring = tostring
local type = type
local tableInsert = table.insert
local tableSort = table.sort
local pairs = pairs
local ipairs = ipairs
local tableConcat = table.concat
local stringRep = string.rep

local EXPECTED_COLOR = colored.green
local RECEIVED_COLOR = colored.red
local DIM_COLOR = colored.dim

local MAX_DIFF_STRING_LENGTH = 20000 ---@readonly 最大差异字符串长度

---@export
local export = {}


--- 渲染差异行
---@param marker string|nil -- "+" / "-" / nil
---@param indent integer
---@param text string
---@return string
local function renderLine(marker, indent, text)
    local prefix = marker and (marker .. " ") or "  "
    local colorize = marker == "+" and RECEIVED_COLOR
        or marker == "-" and EXPECTED_COLOR
        or DIM_COLOR
    return colorize(prefix .. stringRep("  ", indent) .. text)
end

local function formatKey(key)
    local ty = type(key)
    if ty == "string" then
        if key:match("^[%a_][%w_]*$") then
            return key
        end
        return stringFormat("[%q]", key)
    elseif ty == "number" then
        return stringFormat("[%s]", tostring(key))
    end
    return stringFormat("[%s]", tostring(key))
end

local function formatPrimitive(value)
    local ty = type(value)
    if ty == "string" then
        return stringFormat("%q", value)
    elseif ty == "number" or ty == "boolean" or ty == "nil" then
        return tostring(value)
    end
    return stringFormat("<%s>", ty)
end

local function compareKeys(a, b)
    return tostring(a) < tostring(b)
end

local function sortedKeys(obj)
    local keys = {}
    for k, _ in pairs(obj) do
        tableInsert(keys, k)
    end
    tableSort(keys, compareKeys)
    return keys
end

local function applyMarker(marker, minusCount, plusCount)
    if marker == "-" then
        minusCount = minusCount + 1
    elseif marker == "+" then
        plusCount = plusCount + 1
    end
    return minusCount, plusCount
end

---@param entries table[] 差异行表
---@param marker string|nil 差异标记
---@param indent integer 缩进级别
---@param prefix string 前缀字符串
---@param value any 值
---@param includeComma boolean? 是否包含逗号
---@param visited table<any, boolean>? 已访问表
---@return integer minusCount, integer plusCount
local function appendValueLines(entries, marker, indent, prefix, value, includeComma, visited)
    local suffix = includeComma and "," or ""
    local minusCount = 0
    local plusCount = 0
    local valueType = type(value)
    if valueType ~= "table" then
        tableInsert(entries, {
            marker = marker,
            indent = indent,
            text = prefix .. formatPrimitive(value) .. suffix,
        })
        minusCount, plusCount = applyMarker(marker, minusCount, plusCount)
        return minusCount, plusCount
    end

    -- 展开表为逐行结构，标记每个字段的 +/-，保证行数统计准确，同时处理循环引用
    visited = visited or {}
    if visited[value] then
        tableInsert(entries, {
            marker = marker,
            indent = indent,
            text = prefix .. "[Circular]" .. suffix,
        })
        minusCount, plusCount = applyMarker(marker, minusCount, plusCount)
        return minusCount, plusCount
    end

    visited[value] = true
    tableInsert(entries, { marker = marker, indent = indent, text = prefix .. "{" })
    minusCount, plusCount = applyMarker(marker, minusCount, plusCount)
    local keys = sortedKeys(value)
    for _, key in ipairs(keys) do
        local childMinus, childPlus = appendValueLines(
            entries,
            marker,
            indent + 1,
            formatKey(key) .. ": ",
            value[key],
            true,
            visited
        )
        minusCount = minusCount + childMinus
        plusCount = plusCount + childPlus
    end
    tableInsert(entries, { marker = marker, indent = indent, text = "}" .. suffix })
    minusCount, plusCount = applyMarker(marker, minusCount, plusCount)
    visited[value] = nil
    return minusCount, plusCount
end

--- 构建对象差异
---@param expected any
---@param received any
---@param depth integer
---@return table[], integer, integer
local function buildDiff(expected, received, depth)
    depth = depth or 0
    local entries = {}
    local minusCount, plusCount = 0, 0
    if type(expected) ~= "table" or type(received) ~= "table" then
        local minus, plus = appendValueLines(entries, "-", depth, "", expected, false)
        minusCount = minusCount + minus
        plusCount = plusCount + plus
        minus, plus = appendValueLines(entries, "+", depth, "", received, false)
        minusCount = minusCount + minus
        plusCount = plusCount + plus
        return entries, minusCount, plusCount
    end

    tableInsert(entries, { marker = nil, indent = depth, text = "{" })

    local keys = {}
    local seenKeys = {}
    for k, _ in pairs(expected) do
        keys[#keys + 1] = k
        seenKeys[k] = true
    end
    for k, _ in pairs(received) do
        if not seenKeys[k] then
            keys[#keys + 1] = k
        end
    end
    tableSort(keys, compareKeys)

    for _, key in ipairs(keys) do
        local expVal = expected[key]
        local recVal = received[key]
        local linePrefix = formatKey(key) .. " = "
        if expVal == nil then
            local minus, plus = appendValueLines(entries, "+", depth + 1, linePrefix, recVal, true)
            minusCount = minusCount + minus
            plusCount = plusCount + plus
        elseif recVal == nil then
            local minus, plus = appendValueLines(entries, "-", depth + 1, linePrefix, expVal, true)
            minusCount = minusCount + minus
            plusCount = plusCount + plus
        elseif expVal == recVal then
            appendValueLines(entries, nil, depth + 1, linePrefix, expVal, true)
        else
            local same = deepCompare(expVal, recVal, true)
            if same then
                appendValueLines(entries, nil, depth + 1, linePrefix, expVal, true)
            elseif type(expVal) == "table" and type(recVal) == "table" then
                local childEntries, childMinus, childPlus = buildDiff(expVal, recVal, depth + 1)
                if #childEntries > 0 then
                    childEntries[1].text = linePrefix .. childEntries[1].text
                    ---@diagnostic disable-next-line: need-check-nil
                    childEntries[#childEntries].text = childEntries[#childEntries].text .. ","
                    for _, entry in ipairs(childEntries) do
                        tableInsert(entries, entry)
                    end
                    minusCount = minusCount + childMinus
                    plusCount = plusCount + childPlus
                end
            else
                local minus, plus = appendValueLines(entries, "-", depth + 1, linePrefix, expVal, true)
                minusCount = minusCount + minus
                plusCount = plusCount + plus
                minus, plus = appendValueLines(entries, "+", depth + 1, linePrefix, recVal, true)
                minusCount = minusCount + minus
                plusCount = plusCount + plus
            end
        end
    end

    tableInsert(entries, { marker = nil, indent = depth, text = "}" })
    return entries, minusCount, plusCount
end

--- 生成一个字符串用于突出两个值之间的差异.
---@param a any 期望值
---@param b any 接收值
---@param options DiffOptions? 差异选项
---@return string
function export.diff(a, b, options)
    local diffEntries, minusCount, plusCount = buildDiff(a, b, 0)
    if minusCount == 0 and plusCount == 0 then
        return DIM_COLOR(i18n("比较值在视觉上没有差异"))
    end
    local lines = {
        EXPECTED_COLOR(stringFormat("- Expected  - %d", minusCount)),
        RECEIVED_COLOR(stringFormat("+ Received  + %d", plusCount)),
        "",
    }
    for _, entry in ipairs(diffEntries) do
        tableInsert(lines, renderLine(entry.marker, entry.indent, entry.text))
    end

    return tableConcat(lines, "\n")
end

--- 打印差异或字符串化
---@param received any 实际接受值
---@param expected any 期望值
---@param options? DiffOptions 差异选项
---@return string
function export.printDiffOrStringify(received, expected, options)
    -- 如果两个值相等, 则无需展示差异
    if expected == received then
        return ""
    end
    options = normalizeDiffOptions(options)
    -- TODO: 对于均为字符串的情况, 我们需要区分出两个字符串的具体差异

    -- 只要有一侧不是表, 则不需要详尽的差异展示
    if not (type(expected) == "table") or not (type(received) == "table") then
        local printLabel = getLabelPrinter(options.aAnnotation, options.bAnnotation)
        local expectedLine = printLabel(options.aAnnotation) .. printExpected(expected)
        local receivedLine = printLabel(options.bAnnotation) .. printReceived(received)
        return expectedLine .. "\n" .. receivedLine
    end

    local difference = export.diff(expected, received)

    if difference and difference:find("- " .. options.aAnnotation, 1, true) and difference:find("+ " .. options.bAnnotation, 1, true) then
        return difference
    end

    local printLabel = export.getLabelPrinter(options.aAnnotation, options.bAnnotation)


    local expectedLine = printLabel(options.aAnnotation) .. export.printExpected(expected)
    local receivedLine = printLabel(options.bAnnotation) .. (prettyFormat(expected) == prettyFormat(received)
        and i18n("序列化为相同字符串")
        or export.printReceived(received))

    return expectedLine .. "\n" .. receivedLine
end

return export
