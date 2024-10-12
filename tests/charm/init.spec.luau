local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.DevPackages.Charm)
local store = Charm.store

return function()
	local previous = _G.__DEV__

	beforeAll(function()
		_G.__DEV__ = true
	end)

	afterAll(function()
		_G.__DEV__ = previous
	end)

	afterEach(function()
		table.clear(store.listeners :: any)
		table.clear(store.capturing.stack)
		store.capturing.index = 0
	end)
end
