local test = require("../../../tests/test")

test.describe("useSignalState", function()
	require("@self/useSignalState.test")
end)

test.describe("useSignalBinding", function()
	require("@self/useSignalBinding.test")
end)

return {}
