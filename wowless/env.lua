local util = require('wowless.util')
local Mixin = util.mixin

local function dump(api)
  local d = require('pl.pretty').dump
  return function(...)
    for _, x in ipairs({ ... }) do
      d(x)
      if api.UserData(x) then
        print('===[begin userdata]===')
        d(api.UserData(x))
        print('===[ end userdata ]===')
      end
    end
  end
end

local function init(api, loader, taint)
  api.env._G = api.env('getenv')
  api.env.forceinsecure = taint and forceinsecure or function() end
  Mixin(api.env, require('wowapi.loader').loadFunctions(api, loader))
  Mixin(api.env, api.datalua.globals)
  api.env.__wowless = {
    dump = dump(api),
    product = api.product,
  }
end

return {
  init = init,
}
