local suite = require("../suite")

local describe = suite.describe

local function test(name: string)
	describe(name, function()
		return require(`./{name}.spec`) :: any
	end)
end

test("client")
test("server")
test("flatten")
test("patch")
test("validate")

return {}
