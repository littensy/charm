local suite = require("./suite")

local describe = suite.describe
local finish = suite.finish

if not script then
	return
end

_G.__DEV__ = true

describe("charm-sync", function()
	require(script.Parent.CharmSync.spec)
end)

describe("react-charm", function()
	require(script.Parent.ReactCharm.spec)
end)

describe("vide-charm", function()
	require(script.Parent.VideCharm.spec)
end)

finish()
