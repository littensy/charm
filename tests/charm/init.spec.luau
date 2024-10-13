local ReplicatedStorage = game:GetService("ReplicatedStorage")

local store = require(ReplicatedStorage.DevPackages.Charm.store)

return function()
	beforeAll(function()
		_G.__DEV__ = true
	end)

	afterAll(function()
		_G.__DEV__ = nil
	end)

	afterEach(function()
		table.clear(store.listeners :: any)
		table.clear(store.capturing.stack)
		store.capturing.index = 0
	end)
end
