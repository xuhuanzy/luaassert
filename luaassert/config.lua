---@namespace Luaassert

---@export namespace
local config = {
    --- 在抛出异常时是否显示差异
    ---@type boolean
    showDiff = true,

    --- 截断阈值, 超过该阈值的字符串将被截断. 用于处理大型表的显示.
    ---
    --- 设置为`0`时将禁用截断.
    ---@type integer
    truncateThreshold = 40,

    --- 自定义深度相等比较函数.
    ---
    --- 当设置为`nil`时, 将使用默认的深度相等比较函数.
    ---@type fun(a: any, b: any): boolean
    ---@diagnostic disable-next-line: assign-type-mismatch
    deepEqual = nil,
}


return config
