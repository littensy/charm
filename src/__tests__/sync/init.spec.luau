return function()
	local previous = _G.__DEV__

	beforeAll(function()
		_G.__DEV__ = true
	end)

	afterAll(function()
		_G.__DEV__ = previous
	end)
end
