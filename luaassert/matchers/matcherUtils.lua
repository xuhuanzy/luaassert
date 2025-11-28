local colored = require('luaassert.utils.colored')
local stringFormat = string.format
local prettyFormat = require("luaassert.utils.prettyFormat").format
local i18n = require("luaassert.languages.i18n")
local type = type
local tableConcat = table.concat
local tableInsert = table.insert
---@namespace Luaassert

---@export namespace
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

--- 生成匹配器错误消息
---@param hint string 提示
---@param genericMessage string 通用提示
---@param specificMessage string? 具体提示
---@return string
function export.matcherErrorMessage(hint, genericMessage, specificMessage)
  local message = stringFormat('%s\n\n%s: %s', hint, BOLD_WEIGHT('Matcher error'), genericMessage)
  if type(specificMessage) == 'string' then
    message = stringFormat('%s\n\n%s', message, specificMessage)
  end
  return message
end

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
  local isNot = options and options.isNot or false
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
  if isNot then
    hint = hint .. DIM_COLOR(stringFormat('%s.', dimString)) .. 'not_'
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
  return prettyFormat(object, {
    maxDepth = 10,
    maxWidth = 10,
  })
end
export.stringify = stringify

-- 将值压缩成单行文本，表使用紧凑花括号，并携带深度/宽度/长度限制以避免爆长
---@param value any
---@param maxDepth? integer
---@param maxWidth? integer
---@return string
local function stringifyInline(value, maxDepth, maxWidth)
  return prettyFormat(value, {
    maxDepth = maxDepth or 10,
    maxWidth = maxWidth or 10,
  })
end

--- 打印值及其类型, 用于构建详细错误信息
---@param name string 标签
---@param value any 值
---@param printer? fun(value: any): string 打印函数
---@return string
function export.printWithType(name, value, printer)
  local printerFn = printer or stringifyInline
  return stringFormat('%s has type: %s\n%s has value: %s', name, type(value), name, printerFn(value))
end

export.printReceived = function(object)
  return RECEIVED_COLOR(replaceTrailingSpaces(stringify(object)))
end

export.printExpected = function(value)
  return EXPECTED_COLOR(replaceTrailingSpaces(stringify(value)))
end

--- 确保实际值与预期值都是数字
---@param received any
---@param expected any
---@param matcherName string
---@param options MatcherHintOptions?
function export.ensureNumbers(received, expected, matcherName, options)
  if type(received) ~= "number" then
    error(export.matcherErrorMessage(
      export.matcherHint(matcherName, nil, nil, options),
      i18n("接收值(received)必须为number"),
      export.printWithType('Received', received, export.printReceived)
    ))
  end

  if type(expected) ~= "number" then
    error(export.matcherErrorMessage(
      export.matcherHint(matcherName, nil, nil, options),
      i18n("预期值(expected)必须为number"),
      export.printWithType('Expected', expected, export.printExpected)
    ))
  end
end

--- 确保预期长度为非负整数
---@param expected any
---@param matcherName string
---@param options MatcherHintOptions?
function export.ensureExpectedIsNonNegativeInteger(expected, matcherName, options)
  if type(expected) ~= "number" or expected < 0 or math.type(expected) ~= "integer" then
    error(export.matcherErrorMessage(
      export.matcherHint(matcherName, nil, 'expected', options),
      i18n("预期值(expected)必须为非负整数"),
      export.printWithType('Expected', expected, export.printExpected)
    ))
  end
end

--- 确保匹配器未接收预期值
---@param expected any? 传入的预期值
---@param matcherName string 匹配器名称
---@param options MatcherHintOptions? 匹配器选项
function export.ensureNoExpected(expected, matcherName, options)
  if expected ~= nil then
    local matcherString = (options and '' or '[.not]') .. matcherName
    error(export.matcherErrorMessage(
      export.matcherHint(matcherString, nil, '', options),
      i18n('该匹配器不能接收预期(expected)参数'),
      export.printWithType('Expected', expected, export.printExpected)
    ))
  end
end

--- 确保接收

--- 生成标签打印函数, 用于对齐多列文本
---@param ... string 字符串参数列表
---@return fun(string: string): string @返回格式化函数
function export.getLabelPrinter(...)
  local strings = { ... }

  -- 找到最大长度
  local maxLength = 0
  for _, str in ipairs(strings) do
    if #str > maxLength then
      maxLength = #str
    end
  end

  return function(inputString)
    local padding = maxLength - #inputString
    local spaces = string.rep(' ', padding)
    return stringFormat('%s: %s', inputString, spaces)
  end
end


---@class MatcherUtils.PathInfo
---@field traversedPath any[] 已遍历的路径
---@field lastTraversedObject any 最后遍历到的对象
---@field hasEndProp boolean 是否存在最终路径属性
---@field value any 最终路径属性对应的值

--- 获取表对象的路径信息
---@param object any
---@param propertyPath any[]
---@return MatcherUtils.PathInfo
function export.getPath(object, propertyPath)
  if type(propertyPath) ~= "table" then
    error(i18n("propertyPath must be table"))
  end

  local traversedPath = {}
  local current = object
  local lastTraversedObject = object
  local hasEndProp = false
  local value = nil

  for index, segment in ipairs(propertyPath) do
    if type(current) ~= "table" then
      break
    end

    lastTraversedObject = current

    local key = segment
    current = current[key]
    if current == nil then
      break
    end

    traversedPath[index] = segment
    if index == #propertyPath then
      hasEndProp = true
      value = current
    end
  end

  return {
    traversedPath = traversedPath,
    lastTraversedObject = lastTraversedObject,
    hasEndProp = hasEndProp,
    value = value,
  }
end

return export
