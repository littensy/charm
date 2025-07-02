local suite = require("../../../../test/suite")

suite.describe("react-charm", function()
	if not game then
		return suite.skip()
	end
	suite.describe("useAtom", function()
		require("./useAtom.spec")
	end)
	suite.describe("useAtomBinding", function()
		require("./useAtomBinding.spec")
	end)
end)

return {}
