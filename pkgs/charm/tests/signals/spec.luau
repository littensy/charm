local suite = require("@tests/suite")

local describe = suite.describe

local function spec(name: string)
	describe(name, function()
		return require(`./{name}.spec`) :: any
	end)
end

describe("signals", function()
	spec("computed")
	spec("effect")
	spec("effectScope")
	spec("issue_48")
	spec("gc")
	spec("topology")
	spec("untrack")
end)

return {}
