local ReplicatedStorage = game:GetService("ReplicatedStorage")

local store = require(ReplicatedStorage.DevPackages.Charm.store)

return function()
	afterEach(function()
		table.clear(store.listeners :: any)
		table.clear(store.capturing.stack)
		store.capturing.index = 0
	end)
end
