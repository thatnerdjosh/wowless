local plsub = require('pl.template').substitute

local apis = {}
local uiobjects = {}
do
  local lfs = require('lfs')
  local yaml = require('wowapi.yaml')
  for d in lfs.dir('data/api') do
    if d ~= '.' and d ~= '..' then
      local filename = ('data/api/%s'):format(d)
      local cfg = yaml.parseFile(filename)
      if not cfg.debug then
        apis[cfg.name] = cfg
      end
    end
  end
  for d in lfs.dir('data/uiobjects') do
    if d ~= '.' and d ~= '..' then
      local filename = ('data/uiobjects/%s/%s.yaml'):format(d, d)
      local cfg = yaml.parseFile(filename)
      uiobjects[cfg.name] = cfg
    end
  end
end

local inhrev = {}
for _, cfg in pairs(uiobjects) do
  for _, inh in ipairs(cfg.inherits) do
    inhrev[inh] = inhrev[inh] or {}
    table.insert(inhrev[inh], cfg.name)
  end
end

local unavailableApis = {
  CreateForbiddenFrame = true,
  loadstring_untainted = true,
}

local objTypes = {}
for _, cfg in pairs(uiobjects) do
  objTypes[cfg.name] = cfg.objectType or cfg.name
end

do
  local function fixup(cfg)
    for _, inhname in ipairs(cfg.inherits) do
      local inh = uiobjects[inhname]
      fixup(inh)
      for n, m in pairs(inh.methods) do
        cfg.methods[n] = m
      end
    end
  end
  for _, cfg in pairs(uiobjects) do
    fixup(cfg)
  end
end

local frametypes = {}
do
  local function addtype(ty)
    if not frametypes[ty] then
      frametypes[ty] = true
      for _, inh in ipairs(inhrev[ty] or {}) do
        addtype(inh)
      end
    end
  end
  addtype('Frame')
end

local apiNamespaces = {}
do
  for k, v in pairs(apis) do
    local p = k:find('%.')
    if p then
      local name = k:sub(1, p - 1)
      apiNamespaces[name] = apiNamespaces[name] or { methods = {} }
      apiNamespaces[name].methods[k:sub(p + 1)] = v
    end
  end
  for _, v in pairs(apiNamespaces) do
    local flavors = {}
    for _, m in pairs(v.methods) do
      for _, flavor in ipairs(m.flavors or { 'Vanilla', 'TBC', 'Mainline' }) do
        flavors[flavor] = true
      end
    end
    local flist = {}
    for f in pairs(flavors) do
      table.insert(flist, f)
    end
    assert(next(flist))
    v.flavors = #flist ~= 3 and flist or nil
  end
  local unavailable = {
    -- These are grabbed by FrameXML and are unavailable by the time addons run.
    'C_AuthChallenge',
    'C_SecureTransfer',
    'C_StoreSecure',
    'C_WowTokenSecure',
    -- This is documented but does not actually seem to exist.
    'C_ConfigurationWarnings',
  }
  for _, k in ipairs(unavailable) do
    assert(apiNamespaces[k])
    apiNamespaces[k] = nil
  end
end

local function badflavor(flavors)
  local ids = {
    Mainline = 'WOW_PROJECT_MAINLINE',
    TBC = 'WOW_PROJECT_BURNING_CRUSADE_CLASSIC',
    Vanilla = 'WOW_PROJECT_CLASSIC',
  }
  if #flavors == 1 then
    return 'WOW_PROJECT_ID ~= ' .. assert(ids[flavors[1]])
  elseif #flavors == 2 then
    assert(ids[flavors[1]])
    ids[flavors[1]] = nil
    assert(ids[flavors[2]])
    ids[flavors[2]] = nil
    local _, v = next(ids)
    return 'WOW_PROJECT_ID == ' .. v
  else
    error('invalid flavor setting')
  end
end

-- TODO figure out the right approach for these
uiobjects.Minimap = nil
uiobjects.WorldFrame = nil

local text = assert(plsub(
  [[
local _, G = ...
local assertEquals = _G.assertEquals
function G.GeneratedTests()
  local cfuncs = {}
  local function checkFunc(func, isLua)
    assertEquals('function', type(func))
    return {
      getfenv = function()
        assertEquals(_G, getfenv(func))
      end,
      impltype = function()
        assertEquals(
          isLua,
          pcall(function()
            coroutine.create(func)
          end)
        )
      end,
      unique = not isLua and function()
        assertEquals(nil, cfuncs[func])
        cfuncs[func] = true
      end or nil,
    }
  end
  local function checkCFunc(func)
    return checkFunc(func, false)
  end
  local function checkLuaFunc(func)
    return checkFunc(func, true)
  end
  local function checkNotCFunc(func)
    if func ~= nil and not cfuncs[func] then
      return checkLuaFunc(func)
    end
  end
  return {
    apiNamespaces = function()
      local function mkTests(ns, tests)
        for k, v in pairs(ns) do
          -- Anything left over must be a FrameXML-defined function.
          if not tests[k] then
            tests['~' .. k] = function()
              if not cfuncs[v] then
                return checkLuaFunc(v)
              end
            end
          end
        end
        return tests
      end
      return {
> for k, v in sorted(apiNamespaces) do
        $(k) = function()
          local ns = _G.$(k)
> if v.flavors then
          if $(badflavor(v.flavors)) then
            assertEquals('nil', type(ns))
            return
          end
> end
          assertEquals('table', type(ns))
          assert(getmetatable(ns) == nil)
          return mkTests(ns, {
> for mname, method in sorted(v.methods) do
            $(mname) = function()
> if method.flavors and (not v.flavors or #method.flavors < #v.flavors) then
              if $(badflavor(method.flavors)) then
                return checkNotCFunc(ns.$(mname))
              end
> end
> if method.stdlib then
>   local ty = type(tget(_G, method.stdlib))
>   if ty == 'function' then
              return checkCFunc(ns.$(mname))
>   else
              assertEquals('$(ty)', type(ns.$(mname)))
>   end
> else
              return checkCFunc(ns.$(mname))
> end
            end,
> end
          })
        end,
> end
      }
    end,
    globalApis = function()
      local tests = {
> for k, v in sorted(apis) do
> if not k:find('%.') then
        $(k) = function()
> if v.flavors then
          if $(badflavor(v.flavors)) then
            return checkNotCFunc(_G.$(k))
          end
> end
> if unavailableApis[k] then
          assertEquals(_G.SecureCapsuleGet == nil, _G.$(k) ~= nil) -- addon_spec hack
> elseif v.alias then
          assertEquals(_G.$(k), _G.$(v.alias))
> elseif v.stdlib then
>   local ty = type(tget(_G, v.stdlib))
>   if ty == 'function' then
          return checkCFunc(_G.$(k))
>   else
          assertEquals('$(ty)', type(_G.$(k)))
>   end
> elseif v.nowrap then
          return checkLuaFunc(_G.$(k))
> else
          return checkCFunc(_G.$(k))
> end
        end,
> end
> end
      }
      for k, v in pairs(_G) do
        if type(v) == 'function' and not tests[k] then
          tests['~' .. k] = function()
            if not cfuncs[v] then
              return checkLuaFunc(v)
            end
          end
        end
      end
      return tests
    end,
    uiobjects = function()
      local function assertCreateFrame(ty)
        local function process(...)
          assertEquals(1, select('#', ...))
          local frame = ...
          assert(type(frame) == 'table')
          return frame
        end
        return process(CreateFrame(ty))
      end
      local function assertCreateFrameFails(ty)
        local success, err = pcall(function()
          CreateFrame(ty)
        end)
        assert(not success)
        local expectedErr = 'CreateFrame: Unknown frame type \'' .. ty .. '\''
        assertEquals(expectedErr, err:sub(err:len() - expectedErr:len() + 1))
      end
      local GetObjectType = CreateFrame('Frame').GetObjectType
      local indexes = {}
      local function mkTests(name, objectTypeName, tests)
        local frame = assertCreateFrame(name)
        local frame2 = assertCreateFrame(name)
        if name == 'EditBox' then
          frame:Hide() -- captures input focus otherwise
          frame2:Hide() -- captures input focus otherwise
        end
        assertEquals(objectTypeName, GetObjectType(frame))
        local mt = getmetatable(frame)
        assert(mt == getmetatable(frame2))
        if name ~= 'FogOfWarFrame' or WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
          assert(mt ~= nil)
          assert(getmetatable(mt) == nil)
          local mtk, __index = next(mt)
          assertEquals('__index', mtk)
          assertEquals('table', type(__index))
          assertEquals(nil, next(mt, mtk))
          assertEquals(nil, getmetatable(__index))
          assertEquals(nil, indexes[__index])
          indexes[__index] = true
          return {
            contents = function()
              local udk, udv = next(frame)
              assertEquals(udk, 0)
              assertEquals('userdata', type(udv))
              assert(getmetatable(udv) == nil)
              assert(next(frame, udk) == nil)
            end,
            methods = function()
              return tests(__index)
            end,
          }
        end
      end
      return {
> for k, v in sorted(uiobjects) do
        $(k) = function()
> if frametypes[k] and v.flavors then
          if $(badflavor(v.flavors)) then
            assertCreateFrameFails('$(k)')
            return
          end
> end
> if frametypes[k] then
          return mkTests('$(k)', '$(objTypes[k])', function(__index)
            return {
> for mname, method in sorted(v.methods) do
              $(mname) = function()
> if method.flavors then
                if $(badflavor(method.flavors)) then
                  assertEquals('nil', type(__index.$(mname)))
                  return
                end
> end
                return checkCFunc(__index.$(mname))
              end,
> end
            }
          end)
> else
          assertCreateFrameFails('$(k)')
> end
        end,
> end
      }
    end,
  }
end
]],
  {
    _escape = '>',
    _G = _G,
    apiNamespaces = apiNamespaces,
    apis = apis,
    badflavor = badflavor,
    frametypes = frametypes,
    next = next,
    objTypes = objTypes,
    sorted = require('pl.tablex').sort,
    tget = require('wowless.util').tget,
    type = type,
    uiobjects = uiobjects,
    unavailableApis = unavailableApis,
  }
))

-- Hack so test doesn't have side effects.
if select('#', ...) == 0 then
  require('pl.file').write('addon/Wowless/generated.lua', text)
end
return text
