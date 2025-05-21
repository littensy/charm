local suite = require("@self/suite")

if not table.isfrozen(_G) then
	_G.__DEV__ = true
end

require("@packages/charm/tests/spec")

suite.finish()
