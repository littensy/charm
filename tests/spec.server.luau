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
	test("sync")
	test("react")
	test("vide")
end

finish()
