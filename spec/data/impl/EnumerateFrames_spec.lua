describe('EnumerateFrames', function()
  local fn = loadfile('data/impl/EnumerateFrames.lua')
  local function collect(api)
    local t = {}
    local f = fn(api)
    while f ~= nil do
      table.insert(t, f)
      f = fn(api, f)
    end
    return t
  end
  it('works', function()
    local api = require('wowless.api').new(function() end, 0, 'wow')
    assert.same({}, collect(api))
    local f1 = api.CreateFrame('frame')
    assert.same({ f1 }, collect(api))
    local f2 = api.CreateFrame('frame')
    assert.same({ f1, f2 }, collect(api))
    local f3 = api.CreateFrame('frame')
    assert.same({ f1, f2, f3 }, collect(api))
  end)
end)