local ServerScriptService = game:GetService("ServerScriptService")

local suite = require(ServerScriptService.Tests.suite)

suite.describe("vide-charm", function()
	suite.describe("useAtom", function()
		require("./useAtom.spec")
	end)
end)

return {}
