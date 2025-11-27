local i18n = require("luaassert.languages.i18n")
local MATCHERS_OBJECT = require("luaassert.matchers.constants").MATCHERS_OBJECT
---@namespace Luaassert

---@export namespace
local export = {}

-- 内部匹配器
---@type table<MatcherFunctionWithContext, MatcherFunctionWithContext>
local InternalMatchers <const> = {
}

if not _G[MATCHERS_OBJECT] then
    ---@type MatcherState
    local state =
    {
        assertionCalls = 0,
        expectedAssertionsNumber = nil,
        isExpectingAssertions = false,
        numPassingAsserts = 0,
        suppressedErrors = {},
    }

    _G[MATCHERS_OBJECT] = {
        -- 自定义相等性测试器
        customEqualityTesters = {},
        -- 所有匹配器
        matchers = {},
        -- 匹配器状态
        state = state,
    }
end

---@return MatcherState
export.getState = function()
    return _G[MATCHERS_OBJECT].state
end

---@param state MatcherState
export.setState = function(state)
    local oldState = _G[MATCHERS_OBJECT].state
    for k, v in pairs(state) do
        oldState[k] = v
    end
end

-- 获取所有匹配器
---@return MatchersObject
export.getMatchers = function()
    return _G[MATCHERS_OBJECT].matchers
end

--- 设置匹配器
---@param matchers MatchersObject
---@param isInternal boolean
export.setMatchers = function(matchers, isInternal)
    local globalMatchers = _G[MATCHERS_OBJECT].matchers
    for name, matcher in pairs(matchers) do
        ---@cast name string
        ---@cast matcher MatcherFunctionWithContext
        if type(matcher) ~= "function" then
            error(i18n("expect.extend: %s 不是有效的匹配器。必须是函数，但它是 %s", name, type(matcher)))
        end
        if isInternal then
            InternalMatchers[matcher] = matcher
        else
            --TODO: 构建不对称匹配器
        end
    end

    -- 将所有匹配器添加到全局匹配器对象
    for name, matcher in pairs(matchers) do
        globalMatchers[name] = matcher
    end
end

---@return Tester[]
export.getCustomEqualityTesters = function()
    return _G[MATCHERS_OBJECT].customEqualityTesters
end

---@param newTesters Tester[]
export.addCustomEqualityTesters = function(newTesters)
    for _, tester in ipairs(newTesters) do
        table.insert(_G[MATCHERS_OBJECT].customEqualityTesters, tester)
    end
end


return export
