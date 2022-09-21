describe('hooksecurefunc', function()
  local hooksecurefunc = loadfile('data/impl/hooksecurefunc.lua')
  it('hooks members', function()
    local log = {}
    local func = function(a, b, c)
      table.insert(log, string.format('func(%d, %d, %d)', a, b, c))
      return a + 1, b + 1, c + 1
    end
    local hook = function(a, b, c)
      table.insert(log, string.format('hook(%d, %d, %d)', a, b, c))
      return a - 1, b - 1, c - 1
    end
    local t = { func = func }
    assert.same({}, { hooksecurefunc(nil, t, 'func', hook) })
    assert.Not.equals(func, t.func)
    assert.Not.equals(func, t.hook)
    assert.same({ 13, 35, 57 }, { t.func(12, 34, 56) })
    assert.same({ 'func(12, 34, 56)', 'hook(12, 34, 56)' }, log)
  end)
  it('unpacks nils', function()
    local function check(...)
      assert.same(4, select('#', ...))
      assert.Nil(select(1, ...))
      assert.same(42, select(2, ...))
      assert.Nil(select(3, ...))
      assert.Nil(select(4, ...))
    end
    local func = function()
      return nil, 42, nil, nil
    end
    local hookWasCalled = false
    local hook = function()
      hookWasCalled = true
    end
    local env = { moocow = func }
    local apienv = {
      getenv = function()
        return env
      end,
    }
    hooksecurefunc(apienv, 'moocow', hook)
    assert.Not.equals(func, env.moocow)
    assert.Not.equals(hook, env.moocow)
    check(env.moocow())
    assert.True(hookWasCalled)
  end)
end)
