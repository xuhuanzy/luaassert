---@namespace Luaassert

---@alias PartialFunction<T> { [P in keyof T]: P extends "__index" and nil or T[P] extends function and T[P]? or T[P]; }

---@class Inverse<T>
---@field not_ T 取反断言

---@alias Tester fun(self: TesterContext, a: any, b: any, customTesters: Tester[]): boolean?

---@alias EqualsFunction fun(a: any, b: any, customTesters?: Tester[], strictCheck?: boolean): boolean

---@class TesterContext
---@field equals EqualsFunction

---@class MatcherUtils
---@field dontThrow fun()
---@field equals EqualsFunction
---@field utils table

---@class MatcherContext
---@field actual any 收到的实际值
---@field isNot boolean 是否取反

---@class ExpectationResult
---@field passed boolean 是否通过断言
---@field message? fun(): string 断言失败消息

---@alias MatcherFunctionWithContext fun(self: MatcherContext, actual: any, ...: any): ExpectationResult

---@alias MatchersObject table<string, MatcherFunctionWithContext>

---@class Error
---@field message string

---@class MatcherState
---@field assertionCalls integer 断言调用次数
---@field expectedAssertionsNumber? integer 预期断言数
---@field isExpectingAssertions boolean 是否正在期待断言
---@field numPassingAsserts integer 通过断言数
---@field suppressedErrors table<integer, Error> 被抑制的错误


--- 匹配器接口
---@class (partial) Matchers<T>
---@field toBe fun(self: self, expected: any) 浅比较实际值与预期值是否相等, 如需深度比较, 请使用 {@link Luaassert.Matchers.toEqual}.
---@field toBeType fun(self: self, expected: "nil"|"number"|"string"|"boolean"|"table"|"function"|"thread"|"userdata") 比较实际值类型与预期类型是否相等
---@field toBeInteger fun(self: self) 实际值是否为整数
---@field toBeGreaterThan fun(self: self, expected: number) 实际值是否大于预期值
---@field toBeGreaterThanOrEqual fun(self: self, expected: number) 实际值是否大于或等于预期值
---@field toBeLessThan fun(self: self, expected: number) 实际值是否小于预期值
---@field toBeLessThanOrEqual fun(self: self, expected: number) 实际值是否小于或等于预期值
---@field toEqual fun(self: self, expected: any) 比较实际值与预期值是否相等, 如果是表, 则进行深度比较.
---@field toBeFalsy fun(self: self) 实际值是否为假值. 仅有`nil`为假值.
---@field toBeTruthy fun(self: self) 实际值是否为真值. 非`nil`值均为真值.
---@field toThrowError fun(self: self, expected?: any) 函数执行时是否抛出指定错误消息




--- 非对称匹配器
---@class AsymmetricMatcher
---@field asymmetricMatch fun(other: any): boolean
---@field toString fun(): string
---@field getExpectedType? fun(): string
---@field toAsymmetricMatcher? fun(): string

--- 非对称匹配器接口, 用于定义各种非对称匹配器方法
---@class AsymmetricMatchers
---@field any fun(sample: any): AsymmetricMatcher
---@field anything fun(): AsymmetricMatcher
---@field arrayContaining fun(sample: any[]): AsymmetricMatcher
---@field arrayOf fun(sample: unknown): AsymmetricMatcher
---@field closeTo fun(sample: number, precision?: number): AsymmetricMatcher
---@field objectContaining fun(sample: {[string]: any}): AsymmetricMatcher
---@field stringContaining fun(sample: string): AsymmetricMatcher
---@field stringMatching fun(sample: string): AsymmetricMatcher
