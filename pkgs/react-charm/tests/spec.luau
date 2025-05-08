local ServerScriptService = game:GetService("ServerScriptService")

local suite = require(ServerScriptService.Tests.suite)

local describe = suite.describe

local function spec(name: string)
	describe(name, function()
		return require(`./{name}.spec`) :: any
	end)
end

describe("react-charm", function()
	spec("useAtom")
end)

return {}
