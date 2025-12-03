local luaassert = require("luaassert")
local expect = luaassert.expect
local mock = luaassert.mock

-- #region toHaveBeenCalled
do
    local spy = mock.fn()
    spy()
    spy(1, "a")

    expect(spy):toHaveBeenCalled()
    expect(spy):toHaveBeenCalledTimes(2)
    expect(spy).not_:toHaveBeenCalledTimes(1)
end
-- #endregion toHaveBeenCalled

-- #region spyOn 支持
do
    local service = {
        value = 0,
        inc = function(self, delta)
            self.value = self.value + delta
            return self.value
        end,
    }

    local spy = mock.spyOn(service, "inc")

    service:inc(2)
    service:inc(3)

    expect(spy):toHaveBeenCalledTimes(2)
    expect(spy):toHaveBeenCalledWith(service, 2)
    expect(spy):toHaveBeenLastCalledWith(service, 3)
    expect(spy):toHaveBeenNthCalledWith(2, service, 3)
    expect(spy).not_:toHaveBeenCalledWith(service, 99)

    spy:mockReturnValue(10)
    local mockedResult = service:inc(1)

    expect(mockedResult):toBe(10)
    expect(spy):toHaveReturnedWith(10)
    expect(spy):toHaveReturnedTimes(3)
    expect(spy):toHaveLastReturnedWith(10)

    spy:mockRestore()
    expect(service:inc(1)):toBe(6)
end
-- #endregion spyOn 支持

-- #region toHaveBeenCalledWith系列
do
    local spy = mock.fn()
    spy(1, "a")
    spy(2, "b")
    spy({ key = "last" })

    expect(spy):toHaveBeenCalledWith(1, "a")
    expect(spy):toHaveBeenLastCalledWith({ key = "last" })
    expect(spy):toHaveBeenNthCalledWith(2, 2, "b")
    expect(spy).not_:toHaveBeenNthCalledWith(1, "nope")
end
-- #endregion toHaveBeenCalledWith系列

-- #region 返回计数与抛错
do
    local spy = mock.fn(function(flag)
        if flag == "boom" then
            error("fail")
        end
        return flag
    end)

    expect(spy).not_:toHaveReturned()

    ---@diagnostic disable-next-line: param-type-mismatch
    local ok = pcall(spy, "boom")
    expect(ok):toBe(false)

    spy("ok")
    expect(spy):toHaveReturned()
    expect(spy):toHaveReturnedTimes(1)
    expect(spy).not_:toHaveReturnedTimes(2)
end
-- #endregion 返回计数与抛错

-- #region toHaveReturnedWith 单返回值
do
    local spy = mock.fn(function(x)
        return x * 2
    end)

    spy(2)

    expect(spy):toHaveReturnedWith(4)
    expect(spy).not_:toHaveReturnedWith(5)
end
-- #endregion toHaveReturnedWith 单返回值

-- #region 多返回值匹配
do
    local spy = mock.fn(function()
        return "alpha", 1, true
    end)

    spy()

    expect(spy):toHaveReturnedWith("alpha", 1, true)
    expect(spy):toHaveLastReturnedWith("alpha", 1, true)
    expect(spy):toHaveNthReturnedWith(1, "alpha", 1, true)
    expect(spy).not_:toHaveReturnedWith("alpha", 2)
end
-- #endregion 多返回值匹配

-- #region 多次调用下的 last/nth 返回值
do
    local spy = mock.fn(function(n)
        if n == 1 then
            return "x", 10
        elseif n == 2 then
            return "y", 20
        end
    end)

    spy(1)
    spy(2)

    expect(spy):toHaveLastReturnedWith("y", 20)
    expect(spy):toHaveNthReturnedWith(1, "x", 10)
    expect(spy).not_:toHaveNthReturnedWith(2, "x", 10)
end
-- #endregion 多次调用下的 last/nth 返回值
