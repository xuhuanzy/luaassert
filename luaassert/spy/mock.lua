local emptyFunction = require("luaassert.util").emptyFunction
-- 这个模块实现了一个非常轻量的 mock/spy 系统，核心目标是对标 Vitest/Jest 的同步行为：
-- 1. vi.fn()/jest.fn() => 通过 fn() 创建可记录调用信息的函数。
-- 2. vi.spyOn()/jest.spyOn() => 包装对象方法，同时支持恢复、清空、重置等能力。
-- 由于 Lua 没有原生 class，我们通过元表来实现 Mock 实例，并显式追踪状态。

local type = type
local select = select
local tableInsert = table.insert
local tableRemove = table.remove
---@namespace Luaassert

-- 调用顺序计数器
local invocationCallCounter = 1

-- 递增调用计数器, 并返回当前值
---@return integer
local function nextInvocationCallCounter()
    local order = invocationCallCounter
    invocationCallCounter = invocationCallCounter + 1
    return order
end

---@return MockContext
local function getDefaultState()
    return {
        calls = {},
        contexts = {},
        results = {},
        invocationCallOrder = {},
        lastCall = nil,
    }
end

---@param original? Procedure|table @原始函数或表
---@return MockConfig
local function getDefaultConfig(original)
    return {
        mockImplementation = nil,
        mockOriginal = original,
        mockName = "mock.fn()",
        onceMockImplementations = {},
    }
end

---@type table<fun(), true>  @还原函数表
local MOCK_RESTORE = setmetatable({}, { __mode = "k" })
---@type table<Mock, true>  @活跃的 mock 实例表
local REGISTERED_MOCKS = setmetatable({}, { __mode = "k" })
---@type table<Mock, MockConfig>  @mock 实例与配置的映射表
local MOCK_CONFIGS = setmetatable({}, { __mode = "k" })

--- 占位符, 用于表示未捕获实例.
local nilInstance = {} ---@readonly

--[[ Mock 类 ----------------------------------------------------------------
Mock 实例是一个可调用表；将元方法 __call 设置为执行 mock 的核心逻辑。
我们在这里实现所有与 Jest 行为对应的方法（mockImplementation、mockReset 等）。
---------------------------------------------------------------------------]]
---@class Mock<T>
---@field package state MockContext
---@field package config MockConfig
---@field mock MockContext<T>
---@field package _isMockFunction true
---@field private name string
---@field private captureInstance? fun(...: any): any @实例捕获函数, 默认捕获第一个参数为实例.
---@field private restoreConfig MockRestoreConfig @还原配置
local Mock = {}
Mock.__index = Mock

---触发 mock 时记录参数, 上下文, 执行结果
---@param self Mock
---@param ... any 调用参数
---@return any @执行结果
Mock.__call = function(self, ...)
    local args = { ... }
    local state = self.state
    local config = self.config
    state.calls[#state.calls + 1] = args
    state.lastCall = args
    state.invocationCallOrder[#state.invocationCallOrder + 1] = nextInvocationCallCounter()

    local context = nilInstance
    if self.captureInstance then
        context = self.captureInstance(...)
    end
    state.contexts[#state.contexts + 1] = context

    local implementation = tableRemove(config.onceMockImplementations, 1)
        or config.mockImplementation
        or config.mockOriginal
        or emptyFunction
    ---@cast implementation function
    local ok, result = pcall(implementation, ...)
    state.results[#state.results + 1] = {
        type = ok and "return" or "throw",
        value = result,
    }

    if not ok then
        error(result, 0)
    end

    return result
end

---返回下一次执行所使用的实现函数
function Mock:getMockImplementation()
    return self.config.onceMockImplementations[1] or self.config.mockImplementation
end

--- 设置模拟实现
---@param implementation Procedure
---@return Mock
function Mock:mockImplementation(implementation)
    self.config.mockImplementation = implementation
    return self
end

--- 接收一个仅执行一次的实现函数, 并在下次调用时使用.
---
--- 当一次性函数耗尽时, 会使用默认实现.
---@param implementation Procedure
---@return Mock
function Mock:mockImplementationOnce(implementation)
    self.config.onceMockImplementations[#self.config.onceMockImplementations + 1] = implementation
    return self
end

function Mock:mockReturnValue(value)
    return self:mockImplementation(function()
        return value
    end)
end

function Mock:mockReturnValueOnce(value)
    return self:mockImplementationOnce(function()
        return value
    end)
end

---清空所有记录但保留当前实现。
function Mock:mockClear()
    self.state.calls = {}
    self.state.contexts = {}
    self.state.results = {}
    self.state.invocationCallOrder = {}
    self.state.lastCall = nil
    return self
end

---重置 mock，将实现还原到创建时的状态。
function Mock:mockReset()
    self:mockClear()
    local config = self.config
    local restoreConfig = self.restoreConfig

    if restoreConfig.resetToMockImplementation then
        config.mockImplementation = restoreConfig.mockImplementation
    else
        config.mockImplementation = nil
    end
    if restoreConfig.resetToMockName then
        config.mockName = self.name or "mock.fn()"
    else
        config.mockName = "mock.fn()"
    end
    config.onceMockImplementations = {}
    return self
end

---对 spyOn 来说，restore 需要把对象方法替换回原始实现。
function Mock:mockRestore()
    self:mockReset()
    return self
end

function Mock:getMockName()
    return self.name or "mock.fn()"
end

--[[ 工厂函数 ---------------------------------------------------------------
createMockInstance 是 FN/Spy 的公共构建逻辑：设置元表、初始化状态、
并把实例注册到全局弱表里，这样全局 API 能触达它们。
---------------------------------------------------------------------------]]
---@param options? MockInstanceOption
---@return Mock
local function createMockInstance(options)
    options = options or {} ---@cast options MockInstanceOption
    if options.restore then
        MOCK_RESTORE[options.restore] = true
    end

    local state = getDefaultState()
    local config = getDefaultConfig(options.originalImplementation)

    local name = options.name or "Mock"
    ---@type PartialFunction<Mock>
    local mock = {
        state = state,
        config = config,
        mock = state, -- state 的别名, 用于外部使用
        _isMockFunction = true,
        name = name,
        captureInstance = options.captureInstance,
        restoreConfig = {
            resetToMockImplementation = options.resetToMockImplementation,
            mockImplementation = options.mockImplementation,
            resetToMockName = options.resetToMockName,
        }
    }
    local mock = setmetatable(mock, Mock)
    ---@cast mock Mock

    -- 重置为 mock 名称, 用于更好的调试效果
    if options.resetToMockName then
        config.mockName = name or "mock.fn()"
    end
    MOCK_CONFIGS[mock] = config
    REGISTERED_MOCKS[mock] = true

    if options.mockImplementation then
        mock:mockImplementation(options.mockImplementation)
    end

    return mock
end

---判断一个值是否为 Mock
---@param fn any
---@return boolean
local function isMockFunction(fn)
    if type(fn) ~= "table" then
        return false
    end
    --[[@cast fn Mock]]
    return fn._isMockFunction == true
end


---@generic T: Procedure
---@param originalImplementation T?
---@return Mock<T>
local function fn(originalImplementation)
    return createMockInstance({
        mockImplementation = originalImplementation,
        resetToMockImplementation = true,
    })
end

--[[ spyOn -----------------------------------------------------------------
spyOn 针对对象/表方法：替换为 mock，同时保留 restore 钩子。
captureContext 会记录 self 以模拟 jest.fn().mock.instances/contexts。
---------------------------------------------------------------------------]]

---默认的上下文捕获函数，返回第一个参数。
---@param ... any
---@return any
local function defaultCaptureContext(...)
    return select(1, ...)
end


---@param object table|userdata
---@param key string|integer
---@return Mock
local function spyOn(object, key)
    assert(object ~= nil, "spyOn: object is required")
    local t = type(object)
    assert(t == "table" or t == "userdata", ("spyOn: cannot spy on value of type '%s'"):format(t))

    local original = object[key]
    assert(type(original) == "function", ("spyOn: property '%s' is not a function"):format(tostring(key)))

    local function restore()
        object[key] = original
    end
    local name = type(key) == "string" and key or ("[%q]"):format(tostring(key))

    local mockInstance = createMockInstance({
        originalImplementation = original,
        restore = restore,
        instanceContext = defaultCaptureContext,
        name = name,
    })

    object[key] = mockInstance
    return mockInstance
end

--[[ 全局操作 ---------------------------------------------------------------
Vitest 暴露 clear/reset/restoreAllMocks，我们在 Lua 中同样提供，便于测试环境
一次性处理所有 mock 的状态，尤其适合测试套件之间清理。
---------------------------------------------------------------------------]]
local function clearAllMocks()
    for mockInstance in pairs(REGISTERED_MOCKS) do
        mockInstance:mockClear()
    end
end

local function resetAllMocks()
    for mockInstance in pairs(REGISTERED_MOCKS) do
        mockInstance:mockReset()
    end
end

local function restoreAllMocks()
    for restore in pairs(MOCK_RESTORE) do
        restore()
    end
end

return {
    fn = fn,
    spy = fn,
    spyOn = spyOn,
    isMockFunction = isMockFunction,
    clearAllMocks = clearAllMocks,
    resetAllMocks = resetAllMocks,
    restoreAllMocks = restoreAllMocks,
}
