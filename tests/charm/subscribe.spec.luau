local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.DevPackages.Charm)
local atom = Charm.atom
local computed = Charm.computed
local subscribe = Charm.subscribe
local store = require(ReplicatedStorage.DevPackages.Charm.store)
local collect = require(script.Parent.Parent.utils.collect)
local count = require(script.Parent.Parent.utils.count)

return function()
	it("runs on state change", function()
		local current, previous
		local source = atom(0)
		local unsubscribe = subscribe(source, function(...)
			current, previous = ...
		end)

		for index = 1, 3 do
			source(index)
			expect(current).to.equal(index)
			expect(previous).to.equal(index - 1)
		end

		unsubscribe()
		source(4)

		expect(current).to.equal(3)
		expect(previous).to.equal(2)
	end)

	it("prevents garbage collect", function()
		local source = atom(1)
		local updates = 0

		-- Create a new scope to encapsulate variables with a limited lifetime, like
		-- 'unsubscribe' and 'computed', to ensure they are garbage collected.
		--
		-- The idea here is to test whether subscribe() prevents every computed
		-- atom in a chain from being garbage collected. If any are GCed, then
		-- the subscription will stop updating and the test will fail.
		do
			local unsubscribe

			do
				local double = computed(function()
					return source() * 2
				end)

				unsubscribe = subscribe(
					computed(function()
						return double() * 2
					end),
					function()
						updates += 1
					end
				)
			end

			collect()
			source(source() + 1)

			assert(updates == 1, "subscription stopped updating")
			assert(count(store.listeners[source]) == 1, "computed atom was garbage collected")

			unsubscribe()
		end

		collect()

		assert(count(store.listeners[source]) == 0, "computed atom did not collect")
	end)

	it("tracks conditional dependencies", function()
		local condition = atom(false)
		local a = atom(0)
		local b = atom(1)
		local reruns = 0
		local current

		subscribe(function()
			return if condition() then a() else b()
		end, function(state)
			reruns += 1
			current = state
		end)

		condition(true)
		expect(reruns).to.equal(1)
		expect(current).to.equal(0)

		a(1)
		b(2)
		expect(reruns).to.equal(2)
		expect(current).to.equal(1)

		condition(false)
		expect(reruns).to.equal(3)
		expect(current).to.equal(2)
	end)
end
