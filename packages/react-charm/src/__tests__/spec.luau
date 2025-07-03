local suite = require("../../../../test/suite")

suite.describe("useAtom", function()
	require("./useAtom.spec")
end)

suite.describe("useAtomBinding", function()
	require("./useAtomBinding.spec")
end)

return {}
