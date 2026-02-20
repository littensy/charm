local Charm = require("../packages/charm/src")
local test = require("./test")

Charm.flags.strict = true
Charm.flags.frozen = true

local describeInRoblox = test.describeIf(function()
	return game :: any ~= nil
end)

test.describe("charm", function()
	require("../packages/charm/__tests__")
end)

test.describe("charm-sync", function()
	require("../packages/charm-sync/__tests__")
end)

describeInRoblox("react-charm", function()
	require("../packages/react-charm/__tests__")
end)

describeInRoblox("vide-charm", function()
	require("../packages/vide-charm/__tests__")
end)

test.finish()

return {}
