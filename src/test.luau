local Players = game:GetService("Players")

local Charm = require(script.Parent)
local remotes: any = nil

local todoCount = 3

local todos = Charm.atom({
	{ id = 1, text = "Learn about Charm" },
	{ id = 2, text = "Build an app" },
	{ id = 3, text = "Profit" },
})

local function addTodo(text)
	todoCount += 1
	todos(function(state)
		local newState = table.clone(state)
		table.insert(newState, { id = todoCount, text = text })
		return newState
	end)
end

local client = Charm.sync.client({
	atoms = { todos = todos },
})

remotes.init:fire()

remotes.sync:connect(function(payload)
	client:sync(payload)
end)

local server = Charm.sync.server({
	atoms = { todos = todos },
})

server:onSync(function(player, payload)
	print(player.Name, "synced", payload)
end)

Players.PlayerAdded:Connect(function(player)
	server:hydrate(player)
end)
