local stringFormat = string.format
local deepCompare = require("luaassert.util").deepCompare
local colored = require("luaassert.formatters.colored")
local tostring = tostring
local type = type
local tableInsert = table.insert
local tableSort = table.sort
local pairs = pairs
local ipairs = ipairs
local tableConcat = table.concat

local EXPECTED_COLOR = colored.green
local RECEIVED_COLOR = colored.red
local DIM_COLOR = colored.dim

---@export
local export = {}

---@class DiffOptions
---@field aAnnotation? string 期望值标签
---@field bAnnotation? string 接收值标签
---@field includeChangeCounts? boolean 是否包含变更计数

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
    return colorize(prefix .. string.rep("  ", indent) .. text)
end


local function formatKey(key)
    local ty = type(key)
    if ty == "string" then
        return stringFormat("%q", key)
    elseif ty == "number" then
        return stringFormat("[%s]", tostring(key))
    end
    return stringFormat("[%s]", tostring(key))
end

-- 共享的递归格式化函数，传入外层的深度/宽度限制与循环表缓存，避免重复创建闭包
local function formatValue(value, depth, maxDepth, maxWidth, seen)
    local ty = type(value)
    if ty == "string" then
        return stringFormat("%q", value)
    elseif ty == "number" or ty == "boolean" or ty == "nil" then
        return tostring(value)
    elseif ty ~= "table" then
        return stringFormat("<%s>", ty)
    end

    if seen[value] then
        return "[Circular]"
    end
    if depth <= 0 then
        return "{...}"
    end

    seen[value] = true
    local parts = {}
    local indent = string.rep("  ", (maxDepth - depth))
    local nextIndent = indent .. "  "

    parts[#parts + 1] = "{"
    local keys = {}
    for k, _ in pairs(value) do
        tableInsert(keys, k)
    end
    tableSort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)

    local limit = math.min(#keys, maxWidth)
    for i = 1, limit do
        local k = keys[i]
        parts[#parts + 1] = "\n" .. nextIndent ..
            stringFormat("%s: %s", formatKey(k), formatValue(value[k], depth - 1, maxDepth, maxWidth, seen))
        if i < limit then
            parts[#parts] = parts[#parts] .. ","
        end
    end
    if #keys > maxWidth then
        parts[#parts + 1] = "\n" .. nextIndent .. "..."
    end
    parts[#parts + 1] = "\n" .. indent .. "}"

    seen[value] = nil
    return tableConcat(parts)
end
export.formatValue = formatValue

---@param entries table[] 差异行表
---@param marker string|nil 差异标记
---@param indent integer 缩进级别
---@param prefix string 前缀字符串
---@param value any 值
---@param includeComma boolean? 是否包含逗号
---@param visited table<any, boolean>? 已访问表
local function appendValueLines(entries, marker, indent, prefix, value, includeComma, visited)
    local suffix = includeComma and "," or ""
    local valueType = type(value)
    if valueType ~= "table" then
        tableInsert(entries, {
            marker = marker,
            indent = indent,
            text = prefix .. formatValue(value, 3, 5) .. suffix,
        })
        return
    end

    -- 展开表为逐行结构，标记每个字段的 +/-，保证行数统计准确，同时处理循环引用
    visited = visited or {}
    if visited[value] then
        tableInsert(entries, {
            marker = marker,
            indent = indent,
            text = prefix .. "[Circular]" .. suffix,
        })
        return
    end

    visited[value] = true
    tableInsert(entries, { marker = marker, indent = indent, text = prefix .. "{" })
    local keys = {}
    for k, _ in pairs(value) do
        tableInsert(keys, k)
    end
    tableSort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)
    for _, key in ipairs(keys) do
        appendValueLines(entries, marker, indent + 1, formatKey(key) .. ": ", value[key], true, visited)
    end
    tableInsert(entries, { marker = marker, indent = indent, text = "}" .. suffix })
    visited[value] = nil
end


---@param entries table[]
---@return integer, integer
local function countMarkers(entries)
    local minus, plus = 0, 0
    for _, entry in ipairs(entries) do
        if entry.marker == "-" then
            minus = minus + 1
        elseif entry.marker == "+" then
            plus = plus + 1
        end
    end
    return minus, plus
end

--- 构建对象差异
---@param expected any
---@param received any
---@param depth integer
---@return table[]
local function buildDiff(expected, received, depth)
    depth = depth or 0
    local entries = {}
    if type(expected) ~= "table" or type(received) ~= "table" then
        appendValueLines(entries, "-", depth, "", expected, false)
        appendValueLines(entries, "+", depth, "", received, false)
        return entries
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
    tableSort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)

    for _, key in ipairs(keys) do
        local expVal = expected[key]
        local recVal = received[key]
        local linePrefix = formatKey(key) .. ": "
        if expVal == nil then
            appendValueLines(entries, "+", depth + 1, linePrefix, recVal, true)
        elseif recVal == nil then
            appendValueLines(entries, "-", depth + 1, linePrefix, expVal, true)
        else
            local same = deepCompare(expVal, recVal)
            if same then
                appendValueLines(entries, nil, depth + 1, linePrefix, expVal, true)
            elseif type(expVal) == "table" and type(recVal) == "table" then
                local childEntries = buildDiff(expVal, recVal, depth + 1)
                if #childEntries > 0 then
                    childEntries[1].text = linePrefix .. childEntries[1].text
                    ---@diagnostic disable-next-line: need-check-nil
                    childEntries[#childEntries].text = childEntries[#childEntries].text .. ","
                    for _, entry in ipairs(childEntries) do
                        tableInsert(entries, entry)
                    end
                end
            else
                appendValueLines(entries, "-", depth + 1, linePrefix, expVal, true)
                appendValueLines(entries, "+", depth + 1, linePrefix, recVal, true)
            end
        end
    end

    tableInsert(entries, { marker = nil, indent = depth, text = "}" })
    return entries
end

--- 生成一个字符串用于突出两个值之间的差异.
---@param a any 期望值
---@param b any 接收值
---@param options DiffOptions? 差异选项
---@return string
function export.diff(a, b, options)
    local diffEntries = buildDiff(a, b, 0)
    local minusCount, plusCount = countMarkers(diffEntries)
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

return export
