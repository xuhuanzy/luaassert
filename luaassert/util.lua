---@namespace Luaassert

local type = type
local debugGetmetatable = debug.getmetatable
local debugSetmetatable = debug.setmetatable
local tableInsert = table.insert
local next = next
---@diagnostic disable-next-line: access-invisible
local _unpack = table.unpack or unpack
local unpack = function(t, i, j) return _unpack(t, i or 1, j or t.n or #t) end
local pack = function(...) return { n = select("#", ...), ... } end

---@export namespace
local util = {}

util.pack = pack
util.unpack = unpack
util.emptyFunction = function() end

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

local arglist_mt = {}


function util.shallowcopy(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    setmetatable(copy, getmetatable(t))
    for k, v in next, t do
        copy[k] = v
    end
    return copy
end

-----------------------------------------------
-- Copies arguments as a list of arguments
-- @param args the arguments of which to copy
-- @return the copy of the arguments
function util.copyargs(args)
    local copy = {}
    setmetatable(copy, getmetatable(args))
    local match = require 'luaassert.match'
    local spy = require 'luaassert.spy'
    for k, v in pairs(args) do
        copy[k] = ((match.is_matcher(v) or spy.is_spy(v)) and v or util.deepCopy(v))
    end
    return { vals = copy, refs = util.shallowcopy(args) }
end

-----------------------------------------------
-- Clear an arguments or return values list from a table
-- @param arglist the table to clear of arguments or return values and their count
-- @return No return values
function util.cleararglist(arglist)
    for idx = arglist.n, 1, -1 do
        util.tremove(arglist, idx)
    end
    arglist.n = nil
end

-----------------------------------------------
-- Test specs against an arglist in deepcopy and refs flavours.
-- @param args deepcopy arglist
-- @param argsrefs refs arglist
-- @param specs arguments/return values to match against args/argsrefs
-- @return true if specs match args/argsrefs, false otherwise
local function matcharg(args, argrefs, specs)
    local match = require 'luaassert.match'
    for idx, argval in pairs(args) do
        local spec = specs[idx]
        if match.is_matcher(spec) then
            if match.is_ref_matcher(spec) then
                argval = argrefs[idx]
            end
            if not spec(argval) then
                return false
            end
        elseif (spec == nil or not util.deepCompare(argval, spec)) then
            return false
        end
    end

    for idx, spec in pairs(specs) do
        -- only check whether each element has an args counterpart,
        -- actual comparison has been done in first loop above
        local argval = args[idx]
        if argval == nil then
            -- no args counterpart, so try to compare using matcher
            if match.is_matcher(spec) then
                if not spec(argval) then
                    return false
                end
            else
                return false
            end
        end
    end
    return true
end

-----------------------------------------------
-- Find matching arguments/return values in a saved list of
-- arguments/returned values.
-- @param invocations_list list of arguments/returned values to search (list of lists)
-- @param specs arguments/return values to match against argslist
-- @return the last matching arguments/returned values if a match is found, otherwise nil
function util.matchargs(invocations_list, specs)
    -- Search the arguments/returned values last to first to give the
    -- most helpful answer possible. In the cases where you can place
    -- your assertions between calls to check this gives you the best
    -- information if no calls match. In the cases where you can't do
    -- that there is no good way to predict what would work best.
    assert(not util.is_arglist(invocations_list), "expected a list of arglist-object, got an arglist")
    for ii = #invocations_list, 1, -1 do
        local val = invocations_list[ii]
        if matcharg(val.vals, val.refs, specs) then
            return val
        end
    end
    return nil
end

-----------------------------------------------
-- Find matching oncall for an actual call.
-- @param oncalls list of oncalls to search
-- @param args actual call argslist to match against
-- @return the first matching oncall if a match is found, otherwise nil
function util.matchoncalls(oncalls, args)
    for _, callspecs in ipairs(oncalls) do
        -- This lookup is done immediately on *args* passing into the stub
        -- so pass *args* as both *args* and *argsref* without copying
        -- either.
        if matcharg(args, args, callspecs.vals) then
            return callspecs
        end
    end
    return nil
end

-----------------------------------------------
-- table.insert() replacement that respects nil values.
-- The function will use table field 'n' as indicator of the
-- table length, if not set, it will be added.
-- @param t table into which to insert
-- @param pos (optional) position in table where to insert. NOTE: not optional if you want to insert a nil-value!
-- @param val value to insert
-- @return No return values
function util.tinsert(...)
    -- check optional POS value
    local args = { ... }
    local c = select('#', ...)
    local t = args[1]
    local pos = args[2]
    local val = args[3]
    if c < 3 then
        val = pos
        pos = nil
    end
    -- set length indicator n if not present (+1)
    t.n = (t.n or #t) + 1
    if not pos then
        pos = t.n
    elseif pos > t.n then
        -- out of our range
        t[pos] = val
        t.n = pos
    end
    -- shift everything up 1 pos
    for i = t.n, pos + 1, -1 do
        t[i] = t[i - 1]
    end
    -- add element to be inserted
    t[pos] = val
end

-----------------------------------------------
-- table.remove() replacement that respects nil values.
-- The function will use table field 'n' as indicator of the
-- table length, if not set, it will be added.
-- @param t table from which to remove
-- @param pos (optional) position in table to remove
-- @return No return values
function util.tremove(t, pos)
    -- set length indicator n if not present (+1)
    t.n = t.n or #t
    if not pos then
        pos = t.n
    elseif pos > t.n then
        local removed = t[pos]
        -- out of our range
        t[pos] = nil
        return removed
    end
    local removed = t[pos]
    -- shift everything up 1 pos
    for i = pos, t.n do
        t[i] = t[i + 1]
    end
    -- set size, clean last
    t[t.n] = nil
    t.n = t.n - 1
    return removed
end

-----------------------------------------------
-- Checks an element to be callable.
-- The type must either be a function or have a metatable
-- containing an '__call' function.
-- @param object element to inspect on being callable or not
-- @return boolean, true if the object is callable
function util.callable(object)
    if type(object) == 'function' then
        return true
    end
    local mt = debug.getmetatable(object)
    if not mt then
        return false
    end
    return type(rawget(mt, "__call")) == "function"
end

-----------------------------------------------



-----------------------------------------------
-- Extract modifier and namespace keys from list of tokens.
-- @param nspace the namespace from which to match tokens
-- @param tokens list of tokens to search for keys
-- @return table, list of keys that were extracted
function util.extract_keys(nspace, tokens)
    local namespace = require 'luaassert.namespaces'

    -- find valid keys by coalescing tokens as needed, starting from the end
    local keys = {}
    local key = nil
    local i = #tokens
    while i > 0 do
        local token = tokens[i]
        key = key and (token .. '_' .. key) or token

        -- find longest matching key in the given namespace
        local longkey = i > 1 and (tokens[i - 1] .. '_' .. key) or nil
        while i > 1 and longkey and namespace[nspace][longkey] do
            key = longkey
            i = i - 1
            token = tokens[i]
            longkey = (token .. '_' .. key)
        end

        if namespace.modifier[key] or namespace[nspace][key] then
            table.insert(keys, 1, key)
            key = nil
        end
        i = i - 1
    end

    -- if there's anything left we didn't recognize it
    if key then
        error("luaassert: unknown modifier/" .. nspace .. ": '" .. key .. "'", util.errorLevel(2))
    end

    return keys
end

-----------------------------------------------
-- store argument list for return values of a function in a table.
-- The table will get a metatable to identify it as an arglist
function util.make_arglist(...)
    local arglist = { ... }
    arglist.n = select('#', ...) -- add values count for trailing nils
    return setmetatable(arglist, arglist_mt)
end

-----------------------------------------------
-- check a table to be an arglist type.
function util.is_arglist(object)
    return getmetatable(object) == arglist_mt
end

return util
