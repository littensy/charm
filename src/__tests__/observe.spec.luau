local atom = require(script.Parent.Parent.atom)
local observe = require(script.Parent.Parent.observe)

return function()
	it("observes lifetime", function()
		local itemsAtom = atom({ "a", "b", "c" })
		local state = {}

		local cleanup, flush = observe(itemsAtom, function(item, key)
			state[key] = item
			return function()
				state[key] = nil
			end
		end)

		for key = 1, 3 do
			expect(state[key]).to.equal(itemsAtom:get()[key])
		end

		itemsAtom:set({ [4] = "d", [5] = "e", [6] = "f" })
		flush()

		for key = 1, 6 do
			expect(state[key]).to.equal(itemsAtom:get()[key])
		end

		cleanup()

		for key = 1, 6 do
			expect(state[key]).to.equal(nil)
		end
	end)
end
