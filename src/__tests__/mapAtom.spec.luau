local atom = require(script.Parent.Parent.atom)
local mapAtom = require(script.Parent.Parent.mapAtom)
local observe = require(script.Parent.Parent.observe)

return function()
	it("returns mapped atoms", function()
		local itemsAtom = atom({ "a", "b", "c" })
		local mappedAtom = mapAtom(itemsAtom, function(value, key)
			return string.upper(value), key
		end)
		local updates = 0

		mappedAtom.listeners[function()
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
		local mappedAtom = mapAtom(itemsAtom, function(item)
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

		local mappedAtom = mapAtom(itemsAtom, function(item)
			return item, item.key
		end)

		local added = 0
		local deleted = 0

		local _, flush = observe(mappedAtom, function(item, key)
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
		flush()

		expect(added).to.equal(3)
		expect(deleted).to.equal(1)

		itemsAtom({})
		flush()

		expect(added).to.equal(3)
		expect(deleted).to.equal(3)
	end)

	it("unmounts from parent atom", function()
		local itemsAtom = atom({})
		local mappedAtom = mapAtom(itemsAtom, function(item, key)
			return item, key
		end)
		expect((next(itemsAtom.listeners))).to.be.ok()
		mappedAtom:unmount()
		expect((next(itemsAtom.listeners))).to.never.be.ok()
	end)
end
