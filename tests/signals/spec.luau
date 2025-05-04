local suite = require("../suite")

local describe = suite.describe

local function test(name: string)
	describe(name, function()
		return require(`./{name}.spec`) :: any
	end)
end

test("computed")
test("effect")
test("effectScope")
test("issue_48")
test("topology")
test("untrack")

return {}
