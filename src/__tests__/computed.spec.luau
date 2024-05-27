local atom = require(script.Parent.Parent.atom)
local computed = require(script.Parent.Parent.computed)
local store = require(script.Parent.Parent.store)
local collect = require(script.Parent.Parent.utils.collect)
local count = require(script.Parent.Parent.utils.count)

return function()
	it("memoizes the result", function()
		local calls = 0
		local a = atom(1)
		local b = atom(2)
		local double = computed(function()
			calls += 1
			return a() * b()
		end)
		expect(calls).to.equal(1)
		a(1)
		expect(calls).to.equal(1)
		a(2)
		expect(calls).to.equal(2)
		b(3)
		expect(calls).to.equal(3)
		double()
		expect(calls).to.equal(3)
	end)

	it("can be nested", function()
		local source = atom(1)
		local double = computed(function()
			return source() * 2
		end)
		local quadruple = computed(function()
			return double() * 2
		end)
		expect(quadruple()).to.equal(4)
		source(2)
		expect(quadruple()).to.equal(8)
	end)

	it("collects computed atoms", function()
		local source = atom(0)

		computed(function()
			return source()
		end)

		collect()

		assert(count(store.listeners[source]) == 0, "computed atom did not gc")
	end)

	it("collects nested computed atoms", function()
		local source = atom(0)

		do
			-- Declare this in another scope to ensure no references exist at the
			-- time of garbage collection.
			local double = computed(function()
				return source() * 2
			end)

			computed(function()
				return double() * 2
			end)
		end

		collect()

		assert(count(store.listeners[source]) == 0, "nested computed atom did not gc")
	end)
end
