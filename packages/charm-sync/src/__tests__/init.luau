local test = require("../../../tests/test")

test.describe("client", function()
	require("@self/client.test")
end)

test.describe("e2e", function()
	require("@self/e2e.test")
end)

test.describe("utils", function()
	require("@self/utils.test")
end)

test.describe("patch", function()
	require("@self/patch.test")
end)

test.describe("server", function()
	require("@self/server.test")
end)

return {}
