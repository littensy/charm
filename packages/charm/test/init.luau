local test = require("../../tests/test")

test.describe("computed", function()
	require("@self/computed.test")
end)

test.describe("effect", function()
	require("@self/effect.test")
end)

test.describe("effectScope", function()
	require("@self/effectScope.test")
end)

test.describe("gc", function()
	require("@self/gc.test")
end)

test.describe("listen", function()
	require("@self/listen.test")
end)

test.describe("mapped", function()
	require("@self/mapped.test")
end)

test.describe("observe", function()
	require("@self/observe.test")
end)

test.describe("signal", function()
	require("@self/signal.test")
end)

test.describe("subscribe", function()
	require("@self/subscribe.test")
end)

test.describe("topology", function()
	require("@self/topology.test")
end)

test.describe("trigger", function()
	require("@self/trigger.test")
end)

test.describe("untracked", function()
	require("@self/untracked.test")
end)

return {}
