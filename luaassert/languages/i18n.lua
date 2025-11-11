---@diagnostic disable-next-line: access-invisible
local unpack = table.unpack or unpack

local registry = {}
local currentNamespace
local fallbackNamespace

---@class LuaAssert.I18n
local M = {
    -- 设置当前语言
    ---@param namespace string
    setNamespace = function(self, namespace)
        currentNamespace = namespace
        if not registry[currentNamespace] then
            registry[currentNamespace] = {}
        end
    end,

    -- 设置默认语言
    ---@param namespace string
    setFallback  = function(self, namespace)
        fallbackNamespace = namespace
        if not registry[fallbackNamespace] then
            registry[fallbackNamespace] = {}
        end
    end,

    -- 设置语言
    ---@param key string
    ---@param value string
    set          = function(self, key, value)
        registry[currentNamespace][key] = value
    end,

    ---@package
    _registry    = registry
}
setmetatable(M, {
    __call = function(self, key, vars)
        if vars ~= nil and type(vars) ~= "table" then
            error(("expected parameter table to be a table, got '%s'"):format(type(vars)), 2)
        end
        vars = vars or {}
        vars.n = math.max((vars.n or 0), #vars)

        local str = registry[currentNamespace][key] or registry[fallbackNamespace][key]

        if str == nil then
            return nil
        end
        str = tostring(str)
        local strings = {}

        for i = 1, vars.n or #vars do
            table.insert(strings, tostring(vars[i]))
        end

        return #strings > 0 and str:format(unpack(strings)) or str
    end,

    __index = function(self, key)
        return registry[key]
    end
})

M:setFallback('en')
M:setNamespace('en')

return M
