local suite = require("../../../../test/suite")

suite.describe("client", function()
	require("./client.spec")
end)

suite.describe("e2e", function()
	require("./e2e.spec")
end)

suite.describe("utils", function()
	require("./utils.spec")
end)

suite.describe("patch", function()
	require("./patch.spec")
end)

suite.describe("server", function()
	require("./server.spec")
end)

suite.describe("validate", function()
	require("./validate.spec")
end)

return {}
