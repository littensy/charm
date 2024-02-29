local validate = require(script.Parent.Parent.Parent.sync.validate)

return function()
	it("validates inputs", function()
		local cases = {
			array = { value = { 1, 2, 3 }, expected = true },
			array_sparse = { value = { 1, nil :: any, 3 }, expected = true },
			array_sparse_invalid = { value = { [1] = 0, [3] = 0 }, expected = false },

			map_decimal_key = { value = { [1.5] = 0 }, expected = false },
			map_mixed_key = { value = { [1] = 0, a = 0 }, expected = false },

			number = { value = 1, expected = true },
			number_infinity = { value = math.huge, expected = false },
			number_nan = { value = 0 / 0, expected = false },
		}

		for key, case in pairs(cases) do
			local success, result = pcall(function()
				validate(case.value, key, error)
			end)

			if case.expected and not success then
				error(`Expected {key} to be valid, threw {result}`)
			elseif not case.expected and success then
				error(`Expected {key} to be invalid, but it was valid`)
			end
		end
	end)
end
