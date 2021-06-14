local UNIMPLEMENTED = function() end

local uiobjectTypes = {
  actor = {
    inherits = 'parentedobject',
  },
  animationgroup = {
    inherits = 'parentedobject',
  },
  button = {
    inherits = 'frame',
  },
  checkbutton = {
    inherits = 'button',
  },
  editbox = {
    inherits = 'frame',
  },
  font = {
    inherits = 'parentedobject',
  },
  fontfamily = {
    inherits = 'parentedobject',
  },
  fontstring = {
    inherits = 'parentedobject',
  },
  frame = {
    inherits = 'parentedobject',
    mixin = {
      Hide = UNIMPLEMENTED,
      RegisterEvent = UNIMPLEMENTED,
      SetScript = UNIMPLEMENTED,
      SetSize = UNIMPLEMENTED,
    },
  },
  gametooltip = {
    inherits = 'frame',
  },
  messageframe = {
    inherits = 'frame',
  },
  modelscene = {
    inherits = 'parentedobject',
  },
  parentedobject = {
    mixin = {
      SetForbidden = UNIMPLEMENTED,
    },
  },
  playermodel = {
    inherits = 'parentedobject',
  },
  scrollframe = {
    inherits = 'frame',
  },
  slider = {
    inherits = 'frame',
  },
  statusbar = {
    inherits = 'frame',
  },
  texture = {
    inherits = 'parentedobject',
  },
  worldframe = {
    inherits = 'frame',
  },
}

-- The default set of uiobject types are intrinsic.
for _, v in pairs(uiobjectTypes) do
  v.intrinsic = true
end

local function Mixin(t, ...)
  for _, tt in ipairs({...}) do
    for k, v in pairs(tt) do
      t[k] = v
    end
  end
  return t
end

local function _InheritsFrom(a, b)
  a, b = string.lower(a), string.lower(b)
  while a ~= nil and a ~= b do
    a = uiobjectTypes[a].inherits
  end
  return a ~= nil
end

local function _IsIntrinsicType(t)
  local type = uiobjectTypes[string.lower(t)]
  return type and type.intrinsic
end

local function _IsUIObjectType(t)
  return uiobjectTypes[string.lower(t)] ~= nil
end

local function _CreateUIObject(t)
  assert(t.type, 'must specify type for ' .. tostring(t.name))
  local type = uiobjectTypes[string.lower(t.type)]
  assert(type, 'unknown type ' .. t.type .. ' for ' .. tostring(t.name))
  for superType in string.gmatch(t.inherits or '', '[^, ]+') do
    if not uiobjectTypes[string.lower(superType)] then
      print('ignoring unknown inherited type ' .. superType .. ' for ' .. tostring(t.name))
    end
  end
  local virtual = t.virtual
  if t.intrinsic then
    assert(not _IsUIObjectType(t.name), 'already a uiobject type named ' .. t.name)
    virtual = true
  end
  if virtual then
    assert(t.name, 'cannot create anonymous virtual uiobject')
    uiobjectTypes[string.lower(t.name)] = {
      inherits = 'parentedobject',  -- set real inherits
      intrinsic = t.intrinsic,
    }
    return nil
  end
  local obj = {}
  while type do
    Mixin(obj, type.mixin)
    type = uiobjectTypes[type.inherits]
  end
  if t.name then
    _G[t.name] = obj
  end
  return obj
end

local globals = {
  CreateFrame = function(type, name)
    assert(_InheritsFrom(type, 'frame'), type .. ' does not inherit from frame')
    return _CreateUIObject({
      name = name,
      type = type,
    })
  end,
  C_Club = {},
  C_GamePad = {},
  C_ScriptedAnimations = {
    GetAllScriptedAnimationEffects = function()
      return {}  -- UNIMPLEMENTED
    end,
  },
  C_Timer = {
    After = UNIMPLEMENTED,
  },
  C_VoiceChat = {},
  C_Widget = {},
  Enum = setmetatable({}, {
    __index = function(_, k)
      return setmetatable({}, {
        __index = function(_, k2)
          return 'AUTOGENERATED:Enum:' .. k .. ':' .. k2
        end,
      })
    end,
  }),
  FillLocalizedClassList = UNIMPLEMENTED,
  format = string.format,
  GetInventorySlotInfo = function()
    return 'UNIMPLEMENTED'
  end,
  GetItemQualityColor = function()
    return 0, 0, 0  -- UNIMPLEMENTED
  end,
  IsGMClient = UNIMPLEMENTED,
  IsOnGlueScreen = UNIMPLEMENTED,
  issecure = UNIMPLEMENTED,
  newproxy = function()
    return setmetatable({}, {})
  end,
  NUM_LE_ITEM_QUALITYS = 10,  -- UNIMPLEMENTED
  RegisterStaticConstants = UNIMPLEMENTED,
  securecall = UNIMPLEMENTED,
  seterrorhandler = UNIMPLEMENTED,
  UnitRace = function()
    return 'Human', 'Human', 1  -- UNIMPLEMENTED
  end,
  UnitSex = function()
    return 2  -- UNIMPLEMENTED
  end,
}

for k, v in pairs(globals) do
  _G[k] = v
end

local globalStrings = {
  -- luacheck: no max line length
  CONFIRM_CONTINUE = 'Do you wish to continue?',
  GUILD_REPUTATION_WARNING_GENERIC = 'You will lose one rank of guild reputation with your previous guild.',
  REMOVE_GUILDMEMBER_LABEL = 'Are you sure you want to remove %s from the guild?',
  VOID_STORAGE_DEPOSIT_CONFIRMATION = 'Depositing this item will remove all modifications and make it non-refundable and non-tradeable.',
}

for k, v in pairs(globalStrings) do
  _G[k] = v
end

return {
  CreateUIObject = _CreateUIObject,
  IsIntrinsicType = _IsIntrinsicType,
  IsUIObjectType = _IsUIObjectType,
}
