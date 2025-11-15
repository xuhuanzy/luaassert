local i18n = require("luaassert.languages.i18n")

---@type table<string, {[LuaAssert.I18n.Locale]: string}>
local translations = {

}

for key, translation in pairs(translations) do
    i18n:set(key, translation)
end
