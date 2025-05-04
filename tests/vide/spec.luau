local suite = require("../suite")

local describe = suite.describe

local function test(name: string)
	describe(name, function()
		return require(`./{name}.spec`) :: any
	end)
end

test("useAtom")

return {}
