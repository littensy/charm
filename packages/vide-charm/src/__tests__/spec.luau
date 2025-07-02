local suite = require("../../../../test/suite")

suite.describe("vide-charm", function()
	if not game then
		return suite.skip()
	end
	suite.describe("useAtom", function()
		require("./useAtom.spec")
	end)
end)

return {}
