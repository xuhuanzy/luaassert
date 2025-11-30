---@namespace Luaassert

local type = type
local tostring = tostring
local pcall = pcall
local debugGetmetatable = debug.getmetatable
local debugSetmetatable = debug.setmetatable
local next = next
local stringSub = string.sub
local stringLen = string.len
local stringFormat = string.format
local config = require("luaassert.config")
local prettyFormat = require("luaassert.utils.prettyFormat").format
---@diagnostic disable-next-line: access-invisible
local _unpack = table.unpack or unpack
local unpack = function(t, i, j) return _unpack(t, i or 1, j or t.n or #t) end
local pack = function(...) return { n = select("#", ...), ... } end

---@export namespace
local util = {}

util.pack = pack
util.unpack = unpack
util.NOOP = function() end

-- 查询调用栈中第一个不在调用者所在文件中的函数调用层级以报告错误
---@param level integer? 用作调用者源文件的级别
---@return integer @ 报告错误的层级
function util.errorLevel(level)
    level = (level or 1) + 1 --  调用者源文件的级别
    local info = debug.getinfo(level, "S")
    local source = (info or {}).source
    local file = source
    while file and (file == source or source == "=(tail call)") do
        level = level + 1
        info = debug.getinfo(level, "S")
        source = (info or {}).source
    end
    if level > 1 then level = level - 1 end -- 扣除 errorlevel() 本身的调用层级
    return level
end

---深拷贝. 会处理元表.
---@generic T
---@param source T
---@param deepMate boolean? 是否深拷贝元表
---@param mark table?
---@return T
local function deepCopy(source, deepMate, mark)
    if type(source) ~= "table" then return source end
    local copy = {}

    local mark = mark or {}
    if mark[source] then return mark[source] end
    mark[source] = copy

    for k, v in pairs(source) do
        copy[k] = deepCopy(v, deepMate, mark)
    end

    if deepMate then
        debugSetmetatable(copy, deepCopy(debugGetmetatable(source), deepMate, mark))
    else
        -- 设置其元表指向原表的元表
        debugSetmetatable(copy, debugGetmetatable(source))
    end
    return copy
end
util.deepCopy = deepCopy

--- 深度比较两个表格是否相等. 会处理元表.
---@param t1 table 表格1
---@param t2 table 表格2
---@param ignoreMeta boolean? 是否忽略元表
---@param pairCache table? 已比较的表对缓存
---@return boolean @ 是否相等
local function deepCompare(t1, t2, ignoreMeta, pairCache)
    local ty1 = type(t1)
    local ty2 = type(t2)
    -- 非表格类型可以直接进行比较
    if ty1 ~= 'table' or ty2 ~= 'table' then
        return t1 == t2
    end
    -- 如果两个表的引用相等, 则直接返回 true
    if rawequal(t1, t2) then return true end
    -- 如果两个表的元表相等, 且元表中定义了 __eq 方法, 则使用该方法进行比较, 除非忽略元表
    if not ignoreMeta then
        local mt1 = debugGetmetatable(t1)
        local mt2 = debugGetmetatable(t2)
        if mt1 and mt1 == mt2 and mt1.__eq then
            return t1 == t2
        end
    end

    -- 使用表对缓存避免无限递归
    pairCache = pairCache or {}
    local seen = pairCache[t1]
    if seen then
        if seen[t2] then
            return true
        end
    else
        seen = {}
        pairCache[t1] = seen
    end
    seen[t2] = true

    for k1, v1 in next, t1 do
        local v2 = t2[k1]
        if v2 == nil then
            return false
        end
        if not deepCompare(v1, v2, ignoreMeta, pairCache) then
            return false
        end
    end
    for k2, _ in next, t2 do
        -- 检查每个元素是否有t1的对应项, 实际比较已经在上面的循环中完成
        if t1[k2] == nil then return false end
    end

    return true
end
util.deepCompare = deepCompare

-- 检查目标是否有tostring方法
---@param object any
---@return boolean
function util.hasToString(object)
    return type(object) == "string" or type(rawget(debugGetmetatable(object) or {}, "__tostring")) == "function"
end

--- 根据配置截断字符串
---@param value string
---@return string
local function truncate(value)
    local threshold = config.truncateThreshold
    if type(threshold) == "number" and threshold > 0 and stringLen(value) > threshold then
        return stringSub(value, 1, threshold) .. "..."
    end
    return value
end

--- 将任意对象转换为适合断言消息的字符串
---@param value any
---@return string
local function objDisplay(value)
    local valueType = type(value)
    if valueType == "nil" then
        return "nil"
    end
    if valueType == "string" then
        return truncate(stringFormat("%q", value))
    end
    if valueType == "number" or valueType == "boolean" then
        return truncate(tostring(value))
    end

    if util.hasToString(value) then
        local ok, str = pcall(tostring, value)
        if ok and str then
            return truncate(str)
        end
    end

    local ok, formatted = pcall(prettyFormat, value, {
        maxDepth = 2,
        maxWidth = 10,
    })
    if ok and formatted then
        return truncate(formatted)
    end

    return truncate(tostring(value))
end
util.objDisplay = objDisplay

--- 内部使用的标志位键
---@alias InternalFlagKey
---| "ssfi" 起始栈帧
---| "message" 自定义错误消息, 将会附加到断言错误头部
---| "eql" 相等函数
---| "negate" 取反标记
---| "__name" 断言方法名

--- 设置或获取对象的标志位.
---
--- 如果提供了值, 则设置该标志位为指定值; 否则返回该标志位的值.
---@param obj table 目标对象
---@param key InternalFlagKey|string 标志位键名
---@param ... any 标志位值, 仅支持传入单个值.
---@return any
local function flag(obj, key, ...)
    local flags = obj.__flags
    if not flags then
        flags = {}
        obj.__flags = flags
    end
    if select("#", ...) > 0 then
        local value = select(1, ...)
        flags[key] = value
    else
        return flags[key]
    end
end
util.flag = flag

--- 将一个方法添加到一个元表
---@param ctx table 应该为一个元表
---@param name string 方法名
---@param fn function 方法实现
function util.addMethod(ctx, name, fn)
    ctx[name] = fn
end

--- 测试一个对象是否满足表达式.
---@param obj any
---@param expr any
---@return any
function util.test(obj, expr)
    local negate = flag(obj, 'negate') ---@type boolean?
    if negate then
        return not expr
    end
    return expr
end

--- 构建断言错误消息
---@param obj AssertionStatic 构造的断言对象
---@param msg string|(fun(): string) 错误消息
---@param negateMsg string|(fun(): string) 取反错误消息
---@param expected any? 预期值
---@param actual any? 实际值
---@return string
function util.getMessage(obj, msg, negateMsg, expected, actual)
    local negate = flag(obj, 'negate')
    local val = obj._obj
    actual = actual or val
    msg = negate and negateMsg or msg
    local flagMsg = flag(obj, 'message')

    if type(msg) == "function" then
        msg = msg()
    end
    msg = msg or ""

    msg = msg
        :gsub("#%{this%}", objDisplay(val))
        :gsub("#%{act%}", objDisplay(actual))
        :gsub("#%{exp%}", objDisplay(expected))

    if flagMsg then
        return flagMsg .. ": " .. msg
    end
    return msg
end

return util
