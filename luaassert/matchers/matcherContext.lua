---@namespace Luaassert


local MatcherContext = {}


---@param actual any
---@return MatcherContext
function MatcherContext.new(actual)
    ---@type PartialFunction<MatcherContext>
    local self = {
        negate = false,
        actual = actual,
    }
    return setmetatable(self, { __index = MatcherContext })
end

return MatcherContext
