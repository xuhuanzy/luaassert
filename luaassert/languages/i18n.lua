---@diagnostic disable-next-line: access-invisible
local unpack = table.unpack or unpack

---@namespace Luaassert

local registry = {}
---@type string, string
local currentLocale, fallbackLocale

---@alias Luaassert.I18n.Locale "en" | "zh"

---@export namespace
---@class Luaassert.I18n
---@overload fun(key: string, ...: any): string
local M = setmetatable({}, {
    __call = function(self, key, ...)
        local str = registry[currentLocale][key] or registry[fallbackLocale][key] or key
        str = tostring(str)
        if select("#", ...) == 0 then
            return str
        end
        return str:format(...) or str
    end,
})

---@param key string
---@param value {[Luaassert.I18n.Locale]: string}
function M:set(key, value)
    for locale, str in pairs(value) do
        registry[locale][key] = str
    end
end

--- 设置语言环境
---@param locale Luaassert.I18n.Locale
function M:setLocale(locale)
    currentLocale = locale
    if not registry[currentLocale] then
        registry[currentLocale] = {}
    end
end

--- 设置默认语言环境
---@param locale Luaassert.I18n.Locale
function M:setFallbackLocale(locale)
    fallbackLocale = locale
    if not registry[fallbackLocale] then
        registry[fallbackLocale] = {}
    end
end

function M:translate()

end

M:setLocale("en")
M:setFallbackLocale("en")
return M
