local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharmSync = require(ReplicatedStorage.packages["charm-sync"].src)

local patch = CharmSync.patch

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
		local rng = math.random()

		if rng < 1 / 3 then
			continue
		elseif rng < 2 / 3 then
			state.users[user] = nil
		else
			state.users[user] = {
				coins = math.random(1, 2),
				gems = math.random(1, 2),
			}
		end
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
