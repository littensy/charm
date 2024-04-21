local atom = require(script.Parent.Parent.atom)
local derive = require(script.Parent.Parent.derive)
local store = require(script.Parent.Parent.store)
local subscribe = require(script.Parent.Parent.subscribe)
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
		-- 'unsubscribe' and 'derived', to ensure they are garbage collected.
		--
		-- The idea here is to test whether subscribe() prevents every derived
		-- atom in a chain from being garbage collected. If any are GCed, then
		-- the subscription will stop updating and the test will fail.
		do
			local unsubscribe

			do
				local derived = derive(function()
					return source()
				end)

				unsubscribe = subscribe(
					derive(function()
						return derived() * 2
					end),
					function()
						updates += 1
					end
				)
			end

			collect()
			source(source() + 1)

			assert(updates == 1, "subscription stopped updating")
			assert(count(store.listeners[source]) == 1, "derived atom was garbage collected")

			unsubscribe()
		end

		collect()

		assert(count(store.listeners[source]) == 0, "derived atom did not collect")
	end)
end
