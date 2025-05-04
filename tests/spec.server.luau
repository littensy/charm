local suite = require("./suite")

local describe = suite.describe
local finish = suite.finish

local function test(name: string)
	describe(name, function()
		return require(`./{name}/spec`) :: any
	end)
end

test("signals")

if game then
	_G.__DEV__ = true
	test("charm-sync")
	test("react-charm")
	test("vide-charm")
end

finish()
