describe('api', function()
  local data = require('wowapi.data')
  local yaml = require('wowapi.yaml')
  for filename in require('lfs').dir('data/api') do
    if filename ~= '.' and filename ~= '..' then
      assert(filename:sub(-5) == '.yaml', 'invalid file ' .. filename)
      describe(filename, function()
        local t = yaml.parseFile('data/api/' .. filename)
        it('has exactly one implementation', function()
          if t.status == 'autogenerated' or t.status == 'unimplemented' then
            assert.Nil(t.states, 'unimplemented apis cannot specify states')
            assert.Nil(t.returns, 'unimplemented apis cannot specify return values')
            assert.Nil(data.impl[t.name], 'unimplemented apis cannot have an implementation')
          elseif t.status == 'stub' then
            assert.Nil(t.states, 'stub apis cannot specify states')
            assert.same('table', type(t.returns), 'stub apis must specify return value table')
            assert.Nil(data.impl[t.name], 'stub apis cannot have an implementation')
          elseif t.status == 'implemented' then
            assert.Nil(t.returns, 'implemented apis cannot specify return values')
            assert.Not.Nil(data.impl[t.name], 'implemented apis must have an implementation')
          else
            error('unsupported status')
          end
        end)
      end)
    end
  end
end)
