local test = require("../../tests/test")

_G.__ROACT_17_MOCK_SCHEDULER__ = true

test.describe("useSignalState", function()
	require("@self/useSignalState.test")
end)

test.describe("useSignalBinding", function()
	require("@self/useSignalBinding.test")
end)

return {}
