local Charm = require("../packages/charm/src")
local test = require("./test")

Charm.flags.strict = true
Charm.flags.frozen = true

local describeInRoblox = test.describeIf(function()
	return not not game
end)

test.describe("charm", function()
	require("../packages/charm/test")
end)

test.describe("charm-sync", function()
	require("../packages/charm-sync/test")
end)

test.describe("deep-charm", function()
	require("../packages/deep-charm/test")
end)

describeInRoblox("react-charm", function()
	require("../packages/react-charm/test")
end)

describeInRoblox("vide-charm", function()
	require("../packages/vide-charm/test")
end)

test.finish()

return {}
