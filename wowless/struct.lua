local function newtype(name, fieldsarg)
  assert(type(name) == 'string', 'bad name')
  assert(type(fieldsarg) == 'table', 'bad fields')
  local fields = {}
  for k, v in pairs(fieldsarg) do
    assert(type(k) == 'string', 'bad field name')
    assert(type(v) == 'string', 'bad field type')
    fields[k] = v
  end
  local instances = setmetatable({}, { __gc = 'k' })
  local typeproxy = newproxy(true)
  local mt = getmetatable(typeproxy)
  mt.__index = function(ref, k)
    local t = assert(instances[ref], 'bad ref')
    assert(fields[k], 'unknown field')
    return t[k]
  end
  mt.__metatable = name
  mt.__newindex = function(ref, k, v)
    local t = assert(instances[ref], 'bad ref')
    local ty = assert(fields[k], 'unknown field')
    assert(type(v) == ty, 'type mismatch')
    t[k] = v
  end
  return function(init)
    local ref = newproxy(typeproxy)
    instances[ref] = {}
    if init ~= nil then
      for k in pairs(fields) do
        if init[k] ~= nil then
          ref[k] = init[k]
        end
      end
    end
    return ref
  end
end

return newtype
