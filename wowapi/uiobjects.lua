local util = require('wowless.util')
local Mixin = util.mixin
local hlist = require('wowless.hlist')

local function mkBaseUIObjectTypes(api)
  local function toTexture(parent, tex, obj)
    if type(tex) == 'string' or type(tex) == 'number' then
      local t = obj or api.UserData(parent:CreateTexture())
      t:SetTexture(tex)
      return t
    else
      return tex and api.UserData(tex)
    end
  end

  local function flatten(types)
    local result = {}
    local function flattenOne(k)
      local lk = string.lower(k)
      if not result[lk] then
        local ty = types[k]
        local isa = { [lk] = true }
        local metaindex = Mixin({}, ty.mixin)
        for inh in pairs(ty.inherits) do
          flattenOne(inh)
          Mixin(isa, result[string.lower(inh)].isa)
          for mk, mv in pairs(result[string.lower(inh)].metaindex) do
            assert(not metaindex[mk], 'multiple implementations of ' .. mk)
            metaindex[mk] = mv
          end
        end
        result[lk] = {
          constructor = ty.constructor,
          isa = isa,
          metaindex = metaindex,
          name = ty.cfg.objectType or k,
          zombie = ty.cfg.zombie,
        }
      end
    end
    for k in pairs(types) do
      flattenOne(k)
    end
    local t = {}
    for k, v in pairs(result) do
      local sandboxIndex = {}
      for n, f in pairs(v.metaindex) do
        sandboxIndex[n] = debug.newcfunction(function(obj, ...)
          return f(api.UserData(obj), ...)
        end)
      end
      t[k] = {
        constructor = v.constructor,
        hostMT = { __index = v.metaindex },
        isa = v.isa,
        name = v.name,
        sandboxMT = { __index = sandboxIndex },
        zombie = v.zombie,
      }
    end
    return t
  end

  local function wrapstrfn(s, fname, args, ...)
    return assert(loadstring(('local %s=...;return %s'):format(args, s), fname))(...)
  end

  local check = {
    font = function(v)
      if type(v) == 'string' then
        v = api.env[v]
      end
      assert(type(v) == 'table', 'expected font')
      return api.UserData(v)
    end,
    number = function(v)
      return assert(tonumber(v), ('want number, got %s'):format(type(v)))
    end,
    string = function(v)
      return tostring(v)
    end,
    table = function(v)
      assert(type(v) == 'table', 'expected table, got ' .. type(v))
      return v
    end,
    texture = function(v, self)
      local tex = toTexture(self, v)
      return tex and api.UserData(tex)
    end,
  }

  local uiobjects = {}
  for name, cfg in pairs(api.datalua.uiobjects) do
    local lname = name:lower()
    local function wrap(fname, fn)
      return function(self, ...)
        if not api.InheritsFrom(self.type, lname) then
          error(('invalid self to %s.%s, got %s'):format(name, fname, tostring(self.type)))
        end
        return fn(self, ...)
      end
    end
    local function wrapAll(map)
      local mm = {}
      for k, v in pairs(map) do
        mm[k] = wrap(k, v)
      end
      return mm
    end
    local constructor = wrapstrfn(cfg.constructor, name, 'hlist', hlist)
    local mixin = {}
    for mname, method in pairs(cfg.methods) do
      local fname = name .. ':' .. mname
      mixin[mname] = wrapstrfn(method, fname, 'api,toTexture,check', api, toTexture, check)
    end
    uiobjects[name] = {
      cfg = cfg,
      constructor = constructor,
      inherits = cfg.inherits,
      mixin = wrapAll(mixin),
    }
  end
  return flatten(uiobjects)
end

return mkBaseUIObjectTypes
