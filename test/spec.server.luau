local Charm = require("../packages/charm/src")
local suite = require("./suite")

Charm.flags.strict = true
Charm.flags.frozen = true

suite.describe("charm", function()
	require("../packages/charm/src/__tests__/spec")
end)

suite.describe.ingame("charm-sync", function()
	require("../packages/charm-sync/src/__tests__/spec")
end)

suite.describe.ingame("react-charm", function()
	require("../packages/react-charm/src/__tests__/spec")
end)

suite.describe.ingame("vide-charm", function()
	require("../packages/vide-charm/src/__tests__/spec")
end)

suite.finish()
