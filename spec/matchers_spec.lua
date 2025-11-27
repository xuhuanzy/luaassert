local luaassert = require("luaassert")
local expect = luaassert.expect

-- #region toBe
do
    expect(42):toBe(42)
    expect(nil):toBe(nil)
    expect(true):toBe(true)

    expect("luaassert").not_:toBe("t")
    expect(0).not_:toBe(1)
end
-- #endregion toBe

-- #region toBeTypeOf
do
    expect({}):toBeTypeOf("table")
    expect(function() end):toBeTypeOf("function")
    expect(nil):toBeTypeOf("nil")

    expect(100).not_:toBeTypeOf("string")
    expect("matcher").not_:toBeTypeOf("number")
end
-- #endregion toBeTypeOf

-- #region toBeInteger
do
    expect(3):toBeInteger()
    expect(-10):toBeInteger()
    expect(math.mininteger):toBeInteger()

    expect(3.5).not_:toBeInteger()
    expect("5").not_:toBeInteger()
end
-- #endregion toBeInteger

-- #region toBeCloseTo
do
    expect(0.2):toBeCloseTo(0.21, 1)
    expect(-0.1234):toBeCloseTo(-0.1235, 3)
    expect(math.huge):toBeCloseTo(math.huge)

    expect(0.2).not_:toBeCloseTo(0.4, 2)
    expect(-math.huge).not_:toBeCloseTo(math.huge)
end
-- #endregion toBeCloseTo

-- #region toEqual
do
    local actual = {
        id = 1,
        meta = {
            active = true,
            tags = { "stable", "latest" },
        },
    }

    expect(actual):toEqual({
        id = 1,
        meta = {
            active = true,
            tags = { "stable", "latest" },
        },
    })

    expect({
        history = {
            { event = "bootstrap", ok = true },
            { event = "shutdown",  ok = true },
        },
    }):toEqual({
        history = {
            { event = "bootstrap", ok = true },
            { event = "shutdown",  ok = true },
        },
    })

    expect(actual).not_:toEqual({
        id = 2,
        meta = {
            active = true,
        },
    })

    expect({ metrics = { min = 1 } }).not_:toEqual({ metrics = { min = 2 } })

    -- 数组
    expect({ 1, 2, "3" }):toEqual({ 1, 2, "3" })
    expect({ 1, 2, 3 }).not_:toEqual({ 1, 2, 4 })
end
-- #endregion toEqual

-- #region toBeFalsy
do
    expect(false):toBeFalsy()
    expect(nil):toBeFalsy()

    expect(true).not_:toBeFalsy()
    expect(0).not_:toBeFalsy()
end
-- #endregion toBeFalsy

-- #region toBeTruthy
do
    expect("luaassert"):toBeTruthy()
    expect({}):toBeTruthy()
    expect(0):toBeTruthy()

    expect(nil).not_:toBeTruthy()
    expect(false).not_:toBeTruthy()
end
-- #endregion toBeTruthy

-- #region toThrowError
do
    local function throwString()
        error("matcher failure")
    end
    local function throwTable()
        error({ code = 500, message = "boom" })
    end

    expect(throwString):toThrowError("matcher failure")
    expect(function()
        error("other failure")
    end).not_:toThrowError("matcher failure")

    expect(throwTable):toThrowError({ code = 500, message = "boom" })
    expect(throwTable).not_:toThrowError({ code = 400 })

    expect(function() end).not_:toThrowError("anything")
end
-- #endregion toThrowError

-- #region toMatch
do
    expect("Luaassert is awesome"):toMatch("^Lua")
    expect("Luaassert"):toMatch("assert", true)
    expect("[WARN] ready?"):toMatch("%[WARN%]")

    expect("Luaassert").not_:toMatch("jye", true)
    expect("logger: warn").not_:toMatch("^ERROR")
end
-- #endregion toMatch

-- #region toBeOneOf
do
    expect("green"):toBeOneOf({ "red", "green", "blue" })
    expect(2):toBeOneOf({ 2, 4, 6 })

    expect("yellow").not_:toBeOneOf({ "red", "green" })
    expect(10).not_:toBeOneOf({ 1, 3, 5 })
end
-- #endregion toBeOneOf

-- #region toContain
do
    local letters = { "a", "b", "c" }

    expect(letters):toContain("b")
    expect({ 1, 2, 3, 4 }):toContain(4)
    expect("luaassert matcher"):toContain("matcher")

    expect("luaassert").not_:toContain("rehh")
    expect({ "foo", "bar" }).not_:toContain("baz")
end
-- #endregion toContain

-- #region toContainEqual
do
    local buckets = {
        { id = 1, total = 10 },
        { id = 2, total = 20 },
    }

    expect(buckets):toContainEqual({ id = 2, total = 20 })
    expect({
        { tags = { "a", "b" } },
        { tags = { "c" } },
    }):toContainEqual({ tags = { "a", "b" } })

    expect(buckets).not_:toContainEqual({ id = 3, total = 30 })
    expect({
        { meta = { active = true } },
    }).not_:toContainEqual({ meta = { active = false } })
end
-- #endregion toContainEqual

-- #region toMatchObject
do
    local payload = {
        user = {
            name = "alice",
            role = "admin",
        },
        flags = {
            active = true,
        },
    }

    local invoice = {
        items = {
            {
                type = "apples",
                quantity = 10,
            },
            {
                type = "oranges",
                quantity = 5,
            },
        },
        status = "paid",
    }
    -- 匹配对象的部分属性
    expect(payload):toMatchObject({
        user = {
            role = "admin",
        },
        flags = {
            active = true,
        },
    })

    expect(invoice):toMatchObject({
        items = {
            [2] = {
                type = "oranges",
            },
        },
    })

    expect(payload).not_:toMatchObject({
        user = {
            role = "guest",
        },
    })

    expect(invoice).not_:toMatchObject({
        items = {
            [1] = {
                quantity = 99,
            },
        },
    })
end
-- #endregion toMatchObject

-- #region toHaveProperty
do
    local order = {
        customer = {
            profile = {
                email = "user@example.com",
                phone = "123456",
            },
        },
        totals = {
            items = 3,
        },
        ["P.1"] = '999',
        items = {
            [0] = { sku = "A", qty = 1 },
            [1] = { sku = "B", qty = 2 },
        },
        flags = {
            ready = false,
        },
    }

    expect(order):toHaveProperty({ "customer", "profile", "email" }, "user@example.com")
    expect(order):toHaveProperty({ "items", 0, "sku" }, "A")
    expect(order):toHaveProperty({ "items", 1, "qty" }, 2)
    expect(order):toHaveProperty({ "flags", "ready" })
    expect(order):toHaveProperty({ "P.1" }, '999')


    expect(order).not_:toHaveProperty({ "customer", "profile", "phone" }, "000000")
    expect(order).not_:toHaveProperty({ "items", 2 })
    expect(order).not_:toHaveProperty({ "flags", "ready" }, true)
end
-- #endregion toHaveProperty

-- #region toHaveLength
do
    local packed = table.pack(1, nil, 3)
    local pseudoPacked = { 1, 2, 3, n = 5 }
    local custom = setmetatable({}, {
        __len = function()
            return 5
        end,
    })

    expect(packed):toHaveLength(3)
    expect(pseudoPacked):toHaveLength(5)
    expect(custom):toHaveLength(5)
    expect("luaassert"):toHaveLength(9)

    expect("luaassert").not_:toHaveLength(3)
    expect(pseudoPacked).not_:toHaveLength(5, false)
end
-- #endregion toHaveLength

-- #region toBeGreaterThan
do
    expect(10):toBeGreaterThan(2)
    expect(-1):toBeGreaterThan(-5)
    expect(math.huge):toBeGreaterThan(1e9)

    expect(2).not_:toBeGreaterThan(5)
    expect(0).not_:toBeGreaterThan(0)
end
-- #endregion toBeGreaterThan

-- #region toBeGreaterThanOrEqual
do
    expect(10):toBeGreaterThanOrEqual(10)
    expect(4):toBeGreaterThanOrEqual(3)
    expect(-1):toBeGreaterThanOrEqual(-1)

    expect(4).not_:toBeGreaterThanOrEqual(5)
    expect(-2).not_:toBeGreaterThanOrEqual(1)
end
-- #endregion toBeGreaterThanOrEqual

-- #region toBeLessThan
do
    expect(1):toBeLessThan(2)
    expect(-5):toBeLessThan(-1)
    expect(-math.huge):toBeLessThan(0)

    expect(5).not_:toBeLessThan(3)
    expect(3).not_:toBeLessThan(3)
end
-- #endregion toBeLessThan

-- #region toBeLessThanOrEqual
do
    expect(5):toBeLessThanOrEqual(5)
    expect(-10):toBeLessThanOrEqual(-5)
    expect(-math.huge):toBeLessThanOrEqual(-1)

    expect(7).not_:toBeLessThanOrEqual(3)
    expect(math.huge).not_:toBeLessThanOrEqual(0)
end
-- #endregion toBeLessThanOrEqual
