# luaassert

一个适用于`Lua 5.4`的断言库.

必须与 [emmylua](https://github.com/EmmyLuaLs/emmylua-analyzer-rust) 配合使用, 得益于语言服务器的强类型系统提示, 因此内部没有做过多的类型检查.

# 断言方法

## 示例

```lua
local luaassert = require("luaassert")
local expect = luaassert.expect
local mock = luaassert.mock

do
    expect(42):toBe(42)
    expect(nil):toBe(nil)
    expect(true):toBe(true)

    expect("luaassert").not_:toBe("t")
    expect(0).not_:toBe(1)
end

-- mock 函数
do
    local spy = mock.fn()
    spy()
    spy(1, "a")

    expect(spy):toHaveBeenCalled()
    expect(spy):toHaveBeenCalledTimes(2)
    expect(spy).not_:toHaveBeenCalledTimes(1)
end

```

## 匹配器

```lua
---@class (partial) Matchers<T>
---@field toBe fun(self: self, expected: any) 断言实际值与预期值是否相等(a == b). 如需深度比较, 请使用 {@link Luaassert.Matchers.toEqual}.
---@field toBeTypeOf fun(self: self, expected: "nil"|"number"|"string"|"boolean"|"table"|"function"|"thread"|"userdata") 断言实际值是否属于接收类型
---@field toBeInteger fun(self: self) 实际值是否为整数
---@field toBeCloseTo fun(self: self, expected: number, precision?: integer) 断言两个数字在给定精度范围内近似相等. 精度默认值为 `2`.
---@field toBeGreaterThan fun(self: self, expected: number) 实际值是否大于预期值
---@field toBeGreaterThanOrEqual fun(self: self, expected: number) 实际值是否大于或等于预期值
---@field toBeLessThan fun(self: self, expected: number) 实际值是否小于预期值
---@field toBeLessThanOrEqual fun(self: self, expected: number) 实际值是否小于或等于预期值
---@field toEqual fun(self: self, expected: any) 比较实际值与预期值是否相等, 如果是表, 则进行深度比较.
---@field toBeFalsy fun(self: self) 实际值是否为假值. 即是否为`nil`或`false`
---@field toBeTruthy fun(self: self) 实际值是否为真值. 即不为`nil`或`false`
---@field toBeOneOf fun(self: self, expected: any[]) 断言某个值是否与所提供数组中的任何值匹配
---@field toContain fun(self: self, expected: any) 断言数组是否包含指定值, 或字符串是否包含给定字面量子串.
---@field toContainEqual fun(self: self, expected: any) 断言数组是否包含与预期值深度相等的元素.
---@field toMatchObject fun(self: self, expected: table) 断言实际表是否包含给定表的字段子集.
---@field toHaveProperty fun(self: self, expectedPath: any[], expectedValue?: any) 断言对象包含指定路径(数组形式), 并可选比较该路径的值(深相等).
---@field toMatch fun(self: self, expected: string, plain?: boolean) 断言字符串是否与指定模式匹配. 当 `plain` 为 `true` 时, 按字符串查找, 允许仅匹配子串.
---@field toThrowError fun(self: self, expected?: any) 函数执行时是否抛出指定错误消息
---@field toHaveLength fun(self: self, expected: integer, useN?: boolean) 字符串或表是否具有指定长度. 当 `useN` 为 `true` 时会使用 `n` 字段表示长度, 默认值为 `true`.
---@field toHaveBeenCalled fun(self: self) 断言函数是否被调用过. 需要将一个 spy 函数传递给 `expect`.
---@field toHaveBeenCalledTimes fun(self: self, expected: integer) 断言函数被调用的次数. 需要将一个 spy 函数传递给 `expect`.
---@field toHaveBeenCalledWith fun(self: self, ...: any) 检查函数是否至少一次被调用, 并带有特定的参数. 需要将一个 spy 函数传递给 `expect`.
---@field toHaveBeenLastCalledWith fun(self: self, ...: any) 检查函数最后一次调用时是否传入了指定参数. 需要将一个 spy 函数传递给 `expect`.
---@field toHaveBeenNthCalledWith fun(self: self, nth: integer, ...: any) 检查函数第 n 次调用时是否传入了指定参数. 需要将一个 spy 函数传递给 `expect`.
---@field toHaveReturned fun(self: self) 断言函数至少成功返回过一次. 需要将一个 spy 函数传递给 `expect`.
---@field toHaveReturnedTimes fun(self: self, expected: integer) 断言函数成功返回的次数是否为预期值. 需要将一个 spy 函数传递给 `expect`.
---@field toHaveReturnedWith fun(self: self, ...: any) 断言函数至少有一次返回值与给定实参相同. 需要将一个 spy 函数传递给 `expect`.
---@field toHaveLastReturnedWith fun(self: self, ...: any) 检查函数最后一次返回的值是否与给定实参相同. 需要将一个 spy 函数传递给 `expect`.
---@field toHaveNthReturnedWith fun(self: self, nth: integer, ...: any) 检查函数第 n 次返回的值是否与给定实参相同. 需要将一个 spy 函数传递给 `expect`.
```