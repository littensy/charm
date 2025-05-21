local ServerScriptService = game:GetService("ServerScriptService")

local suite = require(ServerScriptService.Tests.suite)

suite.describe("react-charm", function()
	suite.describe("useAtom", function()
		require("./useAtom.spec")
	end)
	suite.describe("useAtomBinding", function()
		require("./useAtomBinding.spec")
	end)
end)

return {}
