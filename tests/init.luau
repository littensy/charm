local suite = require("@tests/suite")

if not table.isfrozen(_G) then
	_G.__DEV__ = true
end

require("@pkgs/charm/tests/spec")

suite.finish({
	colors = true,
	verbose = false,
})
