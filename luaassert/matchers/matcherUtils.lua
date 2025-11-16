local colored = require("luaassert.formatters.colored")
local stringFormat = string.format
local deepCompare = require("luaassert.util").deepCompare
local diff = require("luaassert.utils.diff").diff
local formatValue = require("luaassert.utils.diff").formatValue
local tostring = tostring
local type = type
local tableInsert = table.insert
local tableSort = table.sort
local pairs = pairs
local ipairs = ipairs
local tableConcat = table.concat
---@namespace Luaassert

---@export
local export = {}

local SPACE_SYMBOL = '·'
local EXPECTED_COLOR = colored.green
local RECEIVED_COLOR = colored.red
local INVERTED_COLOR = colored.inverse
local BOLD_WEIGHT = colored.bold
local DIM_COLOR = colored.dim
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



--- 打印差异或字符串化
---@param expected any 期望值
---@param received any 接收值
---@param expectedLabel string 期望值标签
---@param receivedLabel string 接收值标签
---@return string
function export.printDiffOrStringify(expected, received, expectedLabel, receivedLabel)
  local expectedIsTable = type(expected) == "table"
  local receivedIsTable = type(received) == "table"

  -- 只要有一侧不是表则直接单行展示
  if not expectedIsTable or not receivedIsTable then
    local simpleLines = {
      EXPECTED_COLOR(stringFormat("Expected: %s", stringifyInline(expected))),
      RECEIVED_COLOR(stringFormat("Received: %s", stringifyInline(received))),
    }
    return tableConcat(simpleLines, "\n")
  end

  local difference = diff(expected, received, {
    aAnnotation = expectedLabel,
    bAnnotation = receivedLabel,
    includeChangeCounts = true,
  })
  return difference
end

return export
