---@namespace Luaassert

local mock = require("luaassert.spy.mock")

local spy = {}

function spy.new(implementation)
    return mock.fn(implementation)
end

function spy.is_spy(value)
    return mock.isMockFunction(value)
end

return spy
