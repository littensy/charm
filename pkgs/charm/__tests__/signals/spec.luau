local suite = require("@tests/suite")

local describe = suite.describe

local function spec(name: string)
	describe(name, function()
		return require(`./{name}.spec`) :: any
	end)
end

spec("computed")
spec("effect")
spec("effectScope")
spec("issue_48")
spec("topology")
spec("untrack")

return {}
