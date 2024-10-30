local ReplicatedStorage = game:GetService("ReplicatedStorage")

local validate = require(ReplicatedStorage.DevPackages.CharmSync.validate)

return function()
	it("validates inputs", function()
		local cases: { [string]: { value: any, expected: any } } = {
			array = { value = { 1, 2, 3 }, expected = true },
			map = { value = { a = 1, b = 2 }, expected = true },
			thread = { value = { coroutine.running() }, expected = false },
			func = { value = { function() end }, expected = false },
			metatable = { value = setmetatable({}, {}), expected = false },
		}

		for key, case in next, cases do
			local success, result = pcall(function()
				validate(case.value, key, "")
			end)

			if case.expected and not success then
				error(`Expected {key} to be valid, threw {result}`)
			elseif not case.expected and success then
				error(`Expected {key} to be invalid, but it was valid`)
			end
		end
	end)
end
