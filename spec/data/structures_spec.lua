describe('structures', function()
  local yaml = require('wowapi.yaml')
  for filename in require('lfs').dir('data/structures') do
    if filename:sub(-5) == '.yaml' then
      describe(filename, function()
        local str = (function()
          local file = io.open('data/structures/' .. filename, 'r')
          local str = file:read('*all')
          file:close()
          return str
        end)()
        local t = yaml.parse(str)
        it('is formatted correctly', function()
          assert.same(str, yaml.pprint(t))
        end)
        it('has the right name', function()
          assert.same(filename:sub(1, -6), t.name)
        end)
        it('has a valid status', function()
          local valid = {
            autogenerated = true,
          }
          assert.Not.Nil(t.status, 'missing status')
          assert.True(valid[t.status], ('invalid status %q'):format(t.status))
        end)
        it('has no extraneous fields', function()
          local fields = {
            fields = true,
            name = true,
            status = true,
          }
          local fieldFields = {
            default = true,
            innerType = true,
            mixin = true,
            name = true,
            nilable = true,
            type = true,
          }
          for k in pairs(t) do
            assert.True(fields[k], ('unexpected field %q'):format(k))
          end
          for _, field in ipairs(t.fields) do
            for k in pairs(field) do
              assert.True(fieldFields[k], ('unexpected field %q'):format(k))
            end
          end
        end)
      end)
    end
  end
end)
