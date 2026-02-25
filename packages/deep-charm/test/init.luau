local test = require("../../tests/test")

test.describe("reactive", function()
	require(`@self/reactive.test`)
end)

test.describe("gc", function()
	require(`@self/gc.test`)
end)

return {}
