return (function(self, text)
  if type(text) == 'number' then
    text = tostring(text)
  end
  u(self).text = type(text) == 'string' and text or nil
end)(...)
