return function()
	local previous = _G.__DEV__

	beforeAll(function()
		_G.__DEV__ = false -- prevent React errors
	end)

	afterAll(function()
		_G.__DEV__ = previous
	end)
end
