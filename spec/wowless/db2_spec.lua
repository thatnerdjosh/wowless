local db2 = require('wowless.db2')
local vstruct = require('vstruct')
local sorted = require('pl.tablex').sort

local header = vstruct.compile([[<
  magic: s4
  x4  -- record_count: u4
  x4  -- field_count: u4
  record_size: u4
  x4  -- string_table_size: u4
  x4  -- table_hash: u4
  x4  -- layout_hash: u4
  x4  -- min_id: u4
  x4  -- max_id: u4
  x4  -- locale: u4
  x2  -- flags: { [ 2 | x15 has_offset_map: b1 ] }
  x2  -- id_index: u2
  total_field_count: u4
  x4  -- bitpacked_data_offset: u4
  x4  -- lookup_column_count: u4
  field_storage_info_size: u4
  x4  -- common_data_size: u4
  pallet_data_size: u4
  section_count: u4
]])

local section_header = vstruct.compile([[<
  x8  -- tact_key_hash: s8
  file_offset: u4
  record_count: u4
  string_table_size: u4
  x4  -- offset_records_end: u4
  id_list_size: u4
  x4  -- relationship_data_size: u4
  x4  -- offset_map_id_count: u4
  x4  -- copy_table_count: u4
]])

local field = vstruct.compile([[<
  x2  -- size: i2
  position: u2
]])

local field_storage_info = vstruct.compile([[<
  field_offset_bits: u2
  field_size_bits: u2
  additional_data_size: u4
  storage_type: u4
  x4  -- cx1: u4
  x4  -- cx2: u4
  x4  -- cx3: u4
]])

local u4 = vstruct.compile('<u4')

local function mkexpected(spec)
  local expected = {}
  for _, s in ipairs(spec.sections) do
    for _, r in ipairs(s.records) do
      local row = { [0] = r.id }
      for k, f in ipairs(r.fields) do
        row[k] = f
      end
      table.insert(expected, row)
    end
  end
  return expected
end

local function mkstrtabs(spec)
  local strtabs = {}
  for i, s in ipairs(spec.sections) do
    local strs = {}
    for _, r in ipairs(s.records) do
      for _, f in ipairs(r.fields) do
        if type(f) == 'string' then
          strs[f] = true
        end
      end
    end
    local strrev = {}
    local strtab = ''
    for k in sorted(strs) do
      strrev[k] = #strtab
      strtab = strtab .. k .. '\0'
    end
    strtabs[i] = {
      data = strtab,
      rev = strrev,
    }
  end
  return strtabs
end

local function mkpallet(spec)
  local vals = {}
  for _ in ipairs(spec.fields) do
    table.insert(vals, {})
  end
  for _, s in ipairs(spec.sections) do
    for _, r in ipairs(s.records) do
      for k, f in ipairs(r.fields) do
        if spec.fields[k] == 'bitpacked_indexed' then
          vals[k][f] = true
        end
      end
    end
  end
  local pallet = {}
  local revs = {}
  for _, v in ipairs(vals) do
    local part = {}
    local rev = {}
    for f in sorted(v) do
      rev[f] = #part
      table.insert(part, u4:write({ f }))
    end
    table.insert(pallet, table.concat(part))
    table.insert(revs, rev)
  end
  return pallet, revs
end

local function spec2data(spec)
  local pallet, palletrevs = mkpallet(spec)
  local pallet_size = #table.concat(pallet)
  local strtabs = mkstrtabs(spec)
  local record_size = 4 * #spec.fields
  local data = {}
  local function write(fmt, t)
    table.insert(data, fmt:write(t))
  end
  write(header, {
    field_storage_info_size = 24 * #spec.fields,
    magic = 'WDC3',
    pallet_data_size = pallet_size,
    record_size = record_size,
    section_count = #spec.sections,
    total_field_count = #spec.fields,
  })
  for i, s in ipairs(spec.sections) do
    write(section_header, {
      file_offset = 112 + 28 * #spec.fields + pallet_size,
      id_list_size = 4 * #s.records,
      record_count = #s.records,
      string_table_size = #strtabs[i].data,
    })
  end
  for i in ipairs(spec.fields) do
    write(field, {
      position = (i - 1) * 4,
    })
  end
  for i, f in ipairs(spec.fields) do
    local storage_type
    if f == 'uncompressed' then
      storage_type = 0
    elseif f == 'bitpacked_indexed' then
      storage_type = 3
    else
      error('invalid field spec')
    end
    write(field_storage_info, {
      additional_data_size = #pallet[i],
      field_offset_bits = (i - 1) * 32,
      field_size_bits = 32,
      storage_type = storage_type,
    })
  end
  table.insert(data, table.concat(pallet))
  for i, s in ipairs(spec.sections) do
    local strrev = strtabs[i].rev
    for j, r in ipairs(s.records) do
      for k, f in ipairs(r.fields) do
        if type(f) == 'string' then
          -- From wowdev.wiki: the relative position from the
          -- beginning of the field where this offset was stored
          -- to the position of the referenced string in the string block.
          f = strrev[f] + (#s.records - j + 1) * record_size - (k - 1) * 4
        end
        if spec.fields[k] == 'bitpacked_indexed' then
          f = palletrevs[k][f]
        end
        write(u4, { f })
      end
    end
    table.insert(data, strtabs[i].data)
    for _, r in ipairs(s.records) do
      write(u4, { r.id })
    end
  end
  return table.concat(data)
end

local function collect(data, sig)
  local rows = {}
  for row in db2.rows(data, sig) do
    table.insert(rows, row)
  end
  return rows
end

describe('db2', function()
  local tests = require('wowapi.yaml').parseFile('spec/wowless/db2tests.yaml')
  for k, v in pairs(tests) do
    it(k, function()
      assert.same(mkexpected(v), collect(spec2data(v), v.sig))
    end)
  end
end)
