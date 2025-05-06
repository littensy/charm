local suite = require("@tests/suite")

local describe = suite.describe
local finish = suite.finish

if not table.isfrozen(_G) then
	_G.__DEV__ = true
end

describe("charm", function()
	require("@pkgs/charm/tests/spec")
end)

finish()
