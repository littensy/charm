local atom = require(script.Parent.Parent.atom)
local derive = require(script.Parent.Parent.derive)
local subscribe = require(script.Parent.Parent.subscribe)

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

		for _ = 1, 1000 do
			-- The idea here is to test whether subscribe() prevents every derived
			-- atom in a chain from being garbage collected. If any are GCed, then
			-- the subscription will stop updating and the test will fail.
			local derived = derive(function()
				return source()
			end)
			subscribe(
				derive(function()
					return derived() * 2
				end),
				function()
					updates += 1
				end
			)
		end

		source(source() + 1)
		task.wait()
		expect(updates).to.equal(1000)
	end)
end
