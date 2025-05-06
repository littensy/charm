local suite = require("@tests/suite")

local finish = suite.finish

if not table.isfrozen(_G) then
	_G.__DEV__ = true
end

require("@pkgs/charm/tests/spec")

finish()
