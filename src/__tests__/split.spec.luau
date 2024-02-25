local atom = require(script.Parent.Parent.atom)
local isAtom = require(script.Parent.Parent.isAtom)
local observe = require(script.Parent.Parent.observe)
local split = require(script.Parent.Parent.split)

return function()
	it("returns split atoms", function()
		local itemsAtom = atom({ "a", "b", "c" })
		local itemAtoms = split(itemsAtom)
		local updates = 0

		itemAtoms.listeners[function()
			updates += 1
		end] = true

		for key = 1, 3 do
			local itemAtom = itemAtoms()[key]
			assert(isAtom(itemAtom), `itemAtom {key} is not an atom; got {typeof(itemAtom)}`)
			expect(itemAtom()).to.equal(itemsAtom()[key])
		end

		local prevAtoms = itemAtoms()
		itemsAtom({ "d", "e", "f" })
		expect(updates).to.equal(1)

		for key = 1, 3 do
			local itemAtom = itemAtoms()[key]
			assert(itemAtom == prevAtoms[key] :: any, `itemAtom {key} is not the same atom; got {typeof(itemAtom)}`)
			expect(itemAtom()).to.equal(itemsAtom()[key])
		end

		itemsAtom({ [1] = "d", [3] = "f" })
		expect(itemAtoms()[2]).to.never.be.ok()
		expect(updates).to.equal(2)
	end)

	it("has writable items", function()
		local itemsAtom = atom({ "a", "b", "c" })
		local itemAtoms = split(itemsAtom)
		local updates = 0

		itemAtoms.listeners[function()
			updates += 1
		end] = true

		itemAtoms()[2]("x")
		expect(updates).to.equal(1)
		expect(itemsAtom()[2]).to.equal("x")
		expect(itemAtoms()[2]()).to.equal("x")
	end)

	it("uses key extractor", function()
		local itemsAtom = atom({ { key = 1 }, { key = 2 }, { key = 3 } })
		local itemAtoms = split(itemsAtom, function(item)
			return item.key
		end)

		for key = 1, 3 do
			local itemAtom = itemAtoms()[key]
			expect(itemAtom()).to.equal(itemsAtom()[key])
		end

		local prevAtoms = itemAtoms()
		itemsAtom({ itemsAtom()[1], itemsAtom()[3] })

		expect(itemAtoms()[1]).to.equal(prevAtoms[1])
		expect(itemAtoms()[1]()).to.equal(itemsAtom()[1])
		expect(itemAtoms()[2]).to.never.be.ok()
		expect(itemAtoms()[3]).to.equal(prevAtoms[3])
		expect(itemAtoms()[3]()).to.equal(itemsAtom()[2])
	end)

	it("allows observe()", function()
		local itemsAtom = atom({
			{ key = 1, value = "a" },
			{ key = 2, value = "b" },
			{ key = 3, value = "c" },
		})
		local itemAtoms = split(itemsAtom, function(item)
			return item.key
		end)

		local added = 0
		local updated = 0
		local deleted = 0

		local _, flush = observe(itemAtoms, function(item, key)
			expect(item()).to.equal(itemsAtom()[key])

			item.listeners[function(value)
				expect(value).to.equal(itemsAtom()[key])
				updated += 1
			end] = true

			added += 1

			return function()
				expect(itemAtoms()[key]).to.never.be.ok()
				deleted += 1
			end
		end)

		expect(added).to.equal(3)
		expect(updated).to.equal(0)
		expect(deleted).to.equal(0)

		itemsAtom({ itemsAtom()[1], itemsAtom()[3] })
		flush()

		expect(added).to.equal(3)
		expect(updated).to.equal(0)
		expect(deleted).to.equal(1)

		itemAtoms()[1]({ key = 1, value = "x" })
		flush()

		expect(added).to.equal(3)
		expect(updated).to.equal(1)
		expect(deleted).to.equal(1)

		itemsAtom({})
		flush()

		expect(added).to.equal(3)
		expect(updated).to.equal(1)
		expect(deleted).to.equal(3)
	end)
end
