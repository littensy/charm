local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.DevPackages.Charm)
local atom = Charm.atom
local computed = Charm.computed
local subscribe = Charm.subscribe
local effect = Charm.effect
local store = require(ReplicatedStorage.DevPackages.Charm.store)

return function()
	it("batches updates", function()
		local source = atom(1)
		local value = 0
		subscribe(source, function()
			value += 1
		end)
		store.batch(function()
			source(2)
			source(3)
			source(4)
		end)
		expect(value).to.equal(1)
	end)

	it("handles duplicate listeners", function()
		local a = atom(1)
		local b = atom(1)
		local value = 0
		effect(function()
			value += 1
			a()
			b()
		end)
		value = 0 -- effect() will run once initially
		store.batch(function()
			a(2)
			b(2)
			a(3)
		end)
		expect(value).to.equal(1)
	end)

	it("batches computed atoms", function()
		local source = atom(1)
		local updates = 0
		local computations = 0
		local double = computed(function()
			computations += 1
			return source() * 2
		end)
		computations = 0 -- computed atoms will run once initially
		subscribe(double, function()
			updates += 1
		end)
		store.batch(function()
			source(2)
			source(3)
			source(4)
		end)
		expect(updates).to.equal(1)
		expect(computations).to.equal(1)
		expect(double()).to.equal(8)
	end)
end
