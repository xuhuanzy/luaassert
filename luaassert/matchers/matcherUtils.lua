local colored = require("luaassert.formatters.colored")
local stringFormat = string.format
local util = require("luaassert.util")
---@namespace Luaassert

---@export
local export = {}

local SPACE_SYMBOL = '·'
local EXPECTED_COLOR = colored.green
local RECEIVED_COLOR = colored.red
local INVERTED_COLOR = colored.inverse
local BOLD_WEIGHT = colored.bold
local DIM_COLOR = colored.dim
local tostring = tostring
local type = type
local tableInsert = table.insert
local tableSort = table.sort
local pairs = pairs
local ipairs = ipairs
local tableConcat = table.concat

export.EXPECTED_COLOR = EXPECTED_COLOR
export.RECEIVED_COLOR = RECEIVED_COLOR
export.INVERTED_COLOR = INVERTED_COLOR
export.BOLD_WEIGHT = BOLD_WEIGHT
export.DIM_COLOR = DIM_COLOR


---@class MatcherHintOptions
---@field comment string? 注释
---@field isNegate boolean? 是否取反
---@field secondArgument string? 第二个参数
---@field expectedColor? fun(arg: string): string 预期值颜色
---@field receivedColor? fun(arg: string): string? 实际值颜色
---@field secondArgumentColor? fun(arg: string): string?? 第二个参数颜色

--- 生成匹配器提示
---@param matcherName string 匹配器名称
---@param received? string 实际值
---@param expected? string 预期值
---@param options MatcherHintOptions? 选项
---@return string
function export.matcherHint(matcherName, received, expected, options)
  received = received or 'received'
  expected = expected or 'expected'
  local comment = options and options.comment or ''
  local isNegated = options and options.isNegate or false
  local secondArgument = options and options.secondArgument or ''
  local expectedColor = options and options.expectedColor or EXPECTED_COLOR
  local receivedColor = options and options.receivedColor or RECEIVED_COLOR
  local secondArgumentColor = options and options.secondArgumentColor or EXPECTED_COLOR

  ---@cast expectedColor fun(arg: string): string
  ---@cast receivedColor fun(arg: string): string
  ---@cast secondArgumentColor fun(arg: string): string

  local hint = ''
  -- 暗淡的字符串
  local dimString = 'expect'
  if received ~= '' then
    hint = hint .. DIM_COLOR(stringFormat('%s(', dimString)) .. receivedColor(received);
    dimString = ')';
  end
  if isNegated then
    hint = hint .. DIM_COLOR(stringFormat('%s.', dimString)) .. 'not'
    dimString = ''
  end
  -- 匹配器名称
  hint = hint .. DIM_COLOR(stringFormat('%s.', dimString)) .. matcherName
  dimString = ''
  if expected == "" then
    dimString = dimString .. '()'
  else
    hint = hint .. DIM_COLOR(stringFormat('%s(', dimString)) .. expectedColor(expected)
    if secondArgument ~= "" then
      hint = hint .. DIM_COLOR(', ') .. secondArgumentColor(secondArgument)
    end
    dimString = ')'
  end
  -- 注释
  if comment ~= "" then
    dimString = dimString .. stringFormat(' -- %s', comment)
  end
  -- 最终提示
  hint = hint .. DIM_COLOR(dimString)
  return hint
end

--- 替换字符串末尾的空格为中间点符号
---@param text string 输入字符串
---@return string @替换后的字符串
local function replaceTrailingSpaces(text)
  local result = text:gsub("[\t ]+$", function(spaces)
    return SPACE_SYMBOL:rep(#spaces)
  end)
  return result
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

--- 字符串化对象
---@param object any 要字符串化的对象
---@param maxDepth number? 最大深度
---@param maxWidth number? 最大宽度
---@return string @字符串化后的对象
local function stringify(object, maxDepth, maxWidth)
  maxDepth = maxDepth or 10
  maxWidth = maxWidth or 10

  local seen = {}
  return formatValue(object, maxDepth, maxDepth, maxWidth, seen)
end

-- 将值压缩成单行文本，表使用紧凑花括号，并携带深度/宽度/长度限制以避免爆长
---@param value any
---@param maxDepth? integer
---@param maxWidth? integer
---@return string
local function stringifyInline(value, maxDepth, maxWidth)
  maxDepth = maxDepth or 5
  maxWidth = maxWidth or 8
  local str = stringify(value, maxDepth, maxWidth)
  str = str:gsub("%s*\n%s*", " ")
  str = str:gsub("%s%s+", " ")
  str = str:gsub("%s*([,%{%}%[%]])%s*", "%1")
  return str
end

export.printReceived = function(object)
  return RECEIVED_COLOR(replaceTrailingSpaces(stringify(object)))
end

export.printExpected = function(value)
  return EXPECTED_COLOR(replaceTrailingSpaces(stringify(value)))
end



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

---@param entries table[]
---@param marker string|nil
---@param indent integer
---@param prefix string
---@param value any
---@param includeComma boolean
---@param visited table<any, boolean>?
local function appendValueLines(entries, marker, indent, prefix, value, includeComma, visited)
  local suffix = includeComma and "," or ""
  local valueType = type(value)
  if valueType ~= "table" then
    tableInsert(entries, {
      marker = marker,
      indent = indent,
      text = prefix .. stringify(value, 3, 5) .. suffix,
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

--- 构建对象差异
---@param expected any
---@param received any
---@param depth integer
---@return table[]
local function buildDiff(expected, received, depth)
  depth = depth or 0

  if type(expected) ~= "table" or type(received) ~= "table" then
    local entries = {}
    appendValueLines(entries, "-", depth, "", expected, false)
    appendValueLines(entries, "+", depth, "", received, false)
    return entries
  end

  local entries = {}
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
      local same = util.deepCompare and util.deepCompare(expVal, recVal)
      if same then
        appendValueLines(entries, nil, depth + 1, linePrefix, expVal, true)
      elseif type(expVal) == "table" and type(recVal) == "table" then
        local childEntries = buildDiff(expVal, recVal, depth + 1)
        if #childEntries > 0 then
          childEntries[1].text = linePrefix .. childEntries[1].text
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

--- 生成完整差异消息
---@param matcherName string
---@param received any
---@param expected any
---@param crumbs any[]?
---@param options MatcherHintOptions
export.formatDiffMessage = function(matcherName, received, expected, crumbs, options)
  local expectedIsTable = type(expected) == "table"
  local receivedIsTable = type(received) == "table"

  -- 只要有一侧不是表，不进入逐行 diff，直接单行展示，避免标记计数与噪音
  if not expectedIsTable or not receivedIsTable then
    local simpleLines = {
      EXPECTED_COLOR(stringFormat("Expected: %s", stringifyInline(expected))),
      RECEIVED_COLOR(stringFormat("Received: %s", stringifyInline(received))),
    }
    return export.matcherHint(matcherName, nil, nil, options) .. "\n\n" .. tableConcat(simpleLines, "\n")
  end

  local diffEntries = buildDiff(expected, received, 0)

  local minusCount, plusCount = countMarkers(diffEntries)
  local lines = {
    EXPECTED_COLOR(stringFormat("- Expected  - %d", minusCount)),
    RECEIVED_COLOR(stringFormat("+ Received  + %d", plusCount)),
    "",
  }

  for _, entry in ipairs(diffEntries) do
    tableInsert(lines, renderLine(entry.marker, entry.indent, entry.text))
  end

  return export.matcherHint(matcherName, nil, nil, options) .. "\n\n" .. tableConcat(lines, "\n")
end

return export
