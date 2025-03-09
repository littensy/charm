local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.DevPackages.charm)
local atom = Charm.atom
local observe = Charm.observe

return function()
	it("observes lifetime", function()
		local itemsAtom = atom({ "a", "b", "c" })
		local state = {}

		local cleanup = observe(itemsAtom, function(item, key)
			state[key] = item
			return function()
				state[key] = nil
			end
		end)

		for key = 1, 3 do
			expect(state[key]).to.equal(itemsAtom()[key])
		end

		itemsAtom({ [4] = "d", [5] = "e", [6] = "f" })

		for key = 1, 6 do
			expect(state[key]).to.equal(itemsAtom()[key])
		end

		cleanup()

		for key = 1, 6 do
			expect(state[key]).to.equal(nil)
		end
	end)
end
