local suite = require("../../../../test/suite")

suite.describe("charm-sync", function()
	if not game then
		return suite.skip()
	end
	suite.describe("client", function()
		require("./client.spec")
	end)
	suite.describe("server", function()
		require("./server.spec")
	end)
	suite.describe("flatten", function()
		require("./flatten.spec")
	end)
	suite.describe("patch", function()
		require("./patch.spec")
	end)
	suite.describe("validate", function()
		require("./validate.spec")
	end)
end)

return {}
