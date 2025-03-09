local ReplicatedStorage = game:GetService("ReplicatedStorage")

local patch = require(ReplicatedStorage.DevPackages["charm-sync"].src.patch)

local USERS = 1000

local function generate()
	local users = {}

	for user = 1, USERS do
		users[user] = {
			coins = math.random(1, 2),
			gems = math.random(1, 2),
		}
	end

	return { users = users }
end

local function update(state)
	state = table.clone(state)
	state.users = table.clone(state.users)

	for user = 1, USERS do
		if math.random() > 0.5 then
			continue
		end

		state.users[user] = {
			coins = math.random(1, 2),
			gems = math.random(1, 2),
		}
	end

	return state
end

return {
	ParameterGenerator = function()
		local state = generate()
		return state, update(state)
	end,
	Functions = {
		diff = function(_, a, b)
			patch.diff(a, b)
		end,
	},
}
