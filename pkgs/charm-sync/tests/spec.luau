local ServerScriptService = game:GetService("ServerScriptService")

local suite = require(ServerScriptService.Tests.suite)

local describe = suite.describe

local function spec(name: string)
	describe(name, function()
		return require(`./{name}.spec`) :: any
	end)
end

describe("charm-sync", function()
	spec("client")
	spec("server")
	spec("flatten")
	spec("patch")
	spec("validate")
end)

return {}
