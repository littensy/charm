local atom = require(script.Parent.Parent.atom)
local derive = require(script.Parent.Parent.derive)
local effect = require(script.Parent.Parent.effect)
local store = require(script.Parent.Parent.store)
local subscribe = require(script.Parent.Parent.subscribe)

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

	it("batches derived atoms", function()
		local source = atom(1)
		local updates = 0
		local computed = 0
		local double = derive(function()
			computed += 1
			return source() * 2
		end)
		computed = 0 -- derived atoms will run once initially
		subscribe(double, function()
			updates += 1
		end)
		store.batch(function()
			source(2)
			source(3)
			source(4)
		end)
		expect(updates).to.equal(1)
		expect(computed).to.equal(1)
		expect(double()).to.equal(8)
	end)
end
