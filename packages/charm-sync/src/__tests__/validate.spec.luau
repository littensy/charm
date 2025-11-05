local suite = require("../../../../test/suite")
local validate = require("../validate")

local test = suite.test

test("validates inputs", function()
	local cases: { [string]: { value: any, expected: any } } = {
		array = { value = { 1, 2, 3 }, expected = true },
		arraySparse = { value = { 1, nil :: any, 3 }, expected = true },
		arraySparseInvalid = { value = { [1] = 0, [3] = 0 }, expected = false },
		mixedTable = { value = { [1] = "foo", a = true }, expected = false },
	}

	for key, case in cases do
		local success, result: any = pcall(validate, case.value)
		if case.expected and not success then
			error(`Expected {key} to be valid, threw {result}`)
		elseif not case.expected and success then
			error(`Expected {key} to be invalid, but it was valid`)
		end
	end
end)

return {}
