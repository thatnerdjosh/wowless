local datalua, cvars, var = ...
var = var:lower()
return tostring(cvars[var] or datalua.cvars[var]) == '1'
