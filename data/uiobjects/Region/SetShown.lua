return (function(self, shown)
  self.shown = not not shown
  api.UpdateVisible(self)
end)(...)
