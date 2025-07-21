local Charm = require("../../Charm")
local CharmSync = require("../")
local suite = require("../../../../test/suite")

local atom = Charm.atom
local validate = CharmSync.validate
local test = suite.test

test("validates inputs", function()
	local cases: { [string]: { value: any, expected: any } } = {
		array = { value = { 1, 2, 3 }, expected = true },
		array_sparse = { value = { 1, nil :: any, 3 }, expected = true },
		array_sparse_invalid = { value = { [1] = 0, [3] = 0 }, expected = false },

		map_decimal_key = { value = { [1.5] = 0 }, expected = false },
		map_infinity_key = { value = { [math.huge] = true }, expected = false },
		map_mixed_key = { value = { [1] = 0, a = 0 }, expected = false },

		nested_atom = { value = atom(0), expected = false },
	}

	for key, case in next, cases do
		local success, result = pcall(function()
			validate(case.value, key)
		end)

		if case.expected and not success then
			error(`Expected {key} to be valid, threw {result}`)
		elseif not case.expected and success then
			error(`Expected {key} to be invalid, but it was valid`)
		end
	end
end)

return {}
