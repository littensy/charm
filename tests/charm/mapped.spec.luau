local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.DevPackages.charm)
local atom = Charm.atom
local mapped = Charm.mapped
local observe = Charm.observe
local store = require(ReplicatedStorage.DevPackages.charm.src.store)

return function()
	it("returns mapped atoms", function()
		local itemsAtom = atom({ "a", "b", "c" })
		local mappedAtom = mapped(itemsAtom, function(value, key)
			return string.upper(value), key
		end)
		local updates = 0

		store.listeners[mappedAtom][function()
			updates += 1
		end] = true

		for key = 1, 3 do
			local item = mappedAtom()[key]
			expect(item).to.equal(string.upper(itemsAtom()[key]))
		end

		itemsAtom({ "d", "e", "f" })
		expect(updates).to.equal(1)

		for key = 1, 3 do
			local item = mappedAtom()[key]
			expect(item).to.equal(string.upper(itemsAtom()[key]))
		end

		itemsAtom({ [1] = "d", [3] = "f" })
		expect(mappedAtom()[2]).to.never.be.ok()
		expect(updates).to.equal(2)
	end)

	it("uses key extractor", function()
		local itemsAtom = atom({ { key = 1 }, { key = 2 }, { key = 3 } })
		local mappedAtom = mapped(itemsAtom, function(item)
			return item, item.key
		end)

		for key = 1, 3 do
			local item = mappedAtom()[key]
			expect(item).to.equal(itemsAtom()[key])
		end

		local previous = mappedAtom()
		itemsAtom({ itemsAtom()[1], itemsAtom()[3] })

		expect(mappedAtom()[1]).to.equal(previous[1])
		expect(mappedAtom()[1]).to.equal(itemsAtom()[1])
		expect(mappedAtom()[2]).to.never.be.ok()
		expect(mappedAtom()[3]).to.equal(previous[3])
		expect(mappedAtom()[3]).to.equal(itemsAtom()[2])
	end)

	it("allows observe()", function()
		local itemsAtom = atom({
			{ key = 1, value = "a" },
			{ key = 2, value = "b" },
			{ key = 3, value = "c" },
		})

		local mappedAtom = mapped(itemsAtom, function(item)
			return item, item.key
		end)

		local added = 0
		local deleted = 0

		observe(mappedAtom, function(item, key)
			expect(item).to.equal(itemsAtom()[key])
			added += 1

			return function()
				expect(mappedAtom()[key]).to.never.be.ok()
				deleted += 1
			end
		end)

		expect(added).to.equal(3)
		expect(deleted).to.equal(0)

		itemsAtom({ itemsAtom()[1], itemsAtom()[3] })

		expect(added).to.equal(3)
		expect(deleted).to.equal(1)

		itemsAtom({})

		expect(added).to.equal(3)
		expect(deleted).to.equal(3)
	end)
end
