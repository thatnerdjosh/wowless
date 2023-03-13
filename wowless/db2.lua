local vstruct = require('vstruct')

local header = vstruct.compile([[<
  magic: s4
  record_count: u4
  field_count: u4
  record_size: u4
  string_table_size: u4
  table_hash: u4
  layout_hash: u4
  min_id: u4
  max_id: u4
  locale: u4
  flags: { [ 2 | x14 use_offset_map: b1 x1 ] }
  id_index: u2
  total_field_count: u4
  bitpacked_data_offset: u4
  lookup_column_count: u4
  field_storage_info_size: u4
  common_data_size: u4
  pallet_data_size: u4
  section_count: u4
]])

local section_header = vstruct.compile([[<
  tact_key_hash: s8
  file_offset: u4
  record_count: u4
  string_table_size: u4
  offset_records_end: u4
  id_list_size: u4
  relationship_data_size: u4
  offset_map_id_count: u4
  copy_table_count: u4
]])

local field = vstruct.compile([[<
  size: i2
  position: u2
]])

local field_storage_info = vstruct.compile([[<
  field_offset_bits: u2
  field_size_bits: u2
  additional_data_size: u4
  storage_type: u4
  cx1: u4
  cx2: u4
  cx3: u4
]])

local id = vstruct.compile('<u4')

local function worker(content, sig)
  assert(sig:sub(1, 1) == '{')
  assert(sig:sub(-1) == '}')
  sig = sig:sub(2, sig:len() - 1)
  local recstr = '<'
  for i = 1, sig:len() do
    local c = sig:sub(i, i)
    assert(c == 's' or c == 'u')
    recstr = recstr .. 'u4'
  end
  local record = vstruct.compile(recstr)
  local cur = vstruct.cursor(content)
  local h = header:read(cur)
  assert(h.magic == 'WDC3')
  assert(h.total_field_count == #sig)
  assert(h.total_field_count * 24 == h.field_storage_info_size)
  assert(h.flags.use_offset_map == false)
  local shs = {}
  for _ = 1, h.section_count do
    local sh = section_header:read(cur)
    assert(sh.record_count * 4 == sh.id_list_size)
    assert(sh.tact_key_hash == '\0\0\0\0\0\0\0\0')
    table.insert(shs, sh)
  end
  local fs = {}
  for i = 1, h.total_field_count do
    local f = field:read(cur)
    local c = sig:sub(i, i)
    assert(f.size == (c == 's' and 0 or 32))
    assert(f.position == (i - 1) * 4)
    table.insert(fs, f)
  end
  local fsis = {}
  for i = 1, h.total_field_count do
    local fsi = field_storage_info:read(cur)
    assert(fsi.field_offset_bits == (i - 1) * 32)
    assert(fsi.cx1 == 0)
    assert(fsi.cx3 == 0)
    local c = sig:sub(i, i)
    if c == 's' then
      assert(fsi.storage_type == 0)
      assert(fsi.field_size_bits == 32)
      assert(fsi.additional_data_size == 0)
      assert(fsi.cx2 == 0)
    elseif c == 'u' then
      assert(fsi.storage_type == 3)
      assert(fsi.field_size_bits == 2)
      assert(fsi.additional_data_size == 12)
      assert(fsi.cx2 == 2)
    else
      error('internal error')
    end
    table.insert(fsis, fsi)
  end
  cur:seek(nil, h.pallet_data_size)
  cur:seek(nil, h.common_data_size)
  local rcur = vstruct.cursor(content)
  local icur = vstruct.cursor(content)
  for i = 1, h.section_count do
    local sh = shs[i]
    assert(cur.pos == sh.file_offset)
    rcur:seek('set', cur.pos)
    local spos = rcur.pos + sh.record_count * h.record_size
    icur:seek('set', spos + sh.string_table_size)
    cur:seek('set', icur.pos + sh.id_list_size)
    cur:seek(nil, sh.copy_table_count * 8)
    cur:seek(nil, sh.offset_map_id_count * 6)
    assert(sh.relationship_data_size == 0)
    cur:seek(nil, sh.offset_map_id_count * 4)
    for _ = 1, sh.record_count do
      local t = { [0] = id:read(icur)[1] }
      local rpos = rcur.pos
      local rec = record:read(rcur, t)
      for j = 1, h.total_field_count do
        local v = rec[j]
        local c = sig:sub(j, j)
        if c == 's' then
          -- TODO this is only correct in simple cases; see the WDC2 docs
          local offset = rpos + v + 4 * (j - 1)
          t[j] = vstruct.read('@' .. offset .. ' z', content)[1]
        elseif c == 'u' then
          t[j] = v
        else
          error('internal error')
        end
      end
      coroutine.yield(t)
    end
  end
  assert(cur.pos == #content)
end

local function rows(content, sig)
  return coroutine.wrap(function()
    worker(content, sig)
  end)
end

return {
  rows = rows,
}
