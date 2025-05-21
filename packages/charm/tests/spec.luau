local suite = require("@test/suite")

require("./signals/spec")

suite.describe("charm", function()
	suite.describe("listen", function()
		require("./listen.spec")
	end)
	suite.describe("mapped", function()
		require("./mapped.spec")
	end)
	suite.describe("observe", function()
		require("./observe.spec")
	end)
	suite.describe("subscribe", function()
		require("./subscribe.spec")
	end)
	suite.describe("untracked", function()
		require("./untracked.spec")
	end)
end)

return {}
