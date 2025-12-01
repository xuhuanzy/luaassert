local Assertion = require("luaassert.assertion")
---@namespace Luaassert

---@export namespace
---@class Expect
---@overload fun<T>(actual: T): Assertion<T>
local expect = {}

local ExpectMeta = {
    ---@param actual any
    __call = function(self, actual)
        return Assertion.new(actual)
    end,
}

setmetatable(expect, ExpectMeta)
return expect
