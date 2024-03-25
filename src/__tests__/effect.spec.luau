local atom = require(script.Parent.Parent.atom)
local effect = require(script.Parent.Parent.effect)

return function()
	it("runs on state change", function()
		local a = atom(0)
		local b = atom(0)
		local current
		local unsubscribe = effect(function()
			current = a() + b()
		end)

		expect(current).to.equal(0)

		for index = 1, 3 do
			a(index)
			expect(current).to.equal(index)
		end

		for index = 1, 3 do
			b(index)
			expect(current).to.equal(a() + index)
		end

		unsubscribe()
		a(4)

		expect(current).to.equal(6)
	end)
end
