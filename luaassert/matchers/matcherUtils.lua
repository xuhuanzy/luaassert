local colored = require("luaassert.formatters.colored")
local stringFormat = string.format
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
--[[ const stringify = (object, maxDepth = 10, maxWidth = 10) => {
  const MAX_LENGTH = 10_000;
  let result;
  try {
    result = (0, _prettyFormat.format)(object, {
      maxDepth,
      maxWidth,
      min: true,
      plugins: PLUGINS
    });
  } catch {
    result = (0, _prettyFormat.format)(object, {
      callToJSON: false,
      maxDepth,
      maxWidth,
      min: true,
      plugins: PLUGINS
    });
  }
  if (result.length >= MAX_LENGTH && maxDepth > 1) {
    return stringify(object, Math.floor(maxDepth / 2), maxWidth);
  } else if (result.length >= MAX_LENGTH && maxWidth > 1) {
    return stringify(object, maxDepth, Math.floor(maxWidth / 2));
  } else {
    return result;
  }
}; ]]
--- 字符串化对象
---@param object any 要字符串化的对象
---@param maxDepth number? 最大深度
---@param maxWidth number? 最大宽度
---@return string @字符串化后的对象
local function stringify(object, maxDepth, maxWidth)
    maxDepth = maxDepth or 10
    maxWidth = maxWidth or 10
    local MAX_LENGTH = 10000
end

export.printReceived = function(object)
    return RECEIVED_COLOR(replaceTrailingSpaces(stringify(object)))
end

export.printExpected = function(value)
    return EXPECTED_COLOR(replaceTrailingSpaces(stringify(value)))
end

return export
