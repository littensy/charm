local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.DevPackages.Charm)
local atom = Charm.atom
local effect = Charm.effect

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

	it("accepts a cleanup function", function()
		local a = atom(0)
		local cleanups = 0
		local unsubscribe = effect(function()
			a()
			return function()
				cleanups += 1
			end
		end)

		expect(cleanups).to.equal(0)
		a(1)
		expect(cleanups).to.equal(1)
		unsubscribe()
		expect(cleanups).to.equal(2)
	end)

	it("tracks conditional dependencies", function()
		local condition = atom(false)
		local a = atom(0)
		local b = atom(1)
		local reruns = 0
		local current

		effect(function()
			reruns += 1
			current = if condition() then a() else b()
		end)

		expect(reruns).to.equal(1)
		expect(current).to.equal(1)

		condition(true)
		expect(reruns).to.equal(2)
		expect(current).to.equal(0)

		a(1)
		b(2)
		expect(reruns).to.equal(3)
		expect(current).to.equal(1)

		condition(false)
		expect(reruns).to.equal(4)
		expect(current).to.equal(2)
	end)

	it("allows self-cleanup", function()
		local a = atom(1)
		local cleanedUp = false
		local cleanup

		cleanup = effect(function()
			if cleanup then
				assert(not cleanedUp, "cleanup ran twice")
				cleanup()
				cleanedUp = true
			end
			a()
		end)

		a(2)
		a(3)
	end)

	it("allows immediate self-cleanup", function()
		local a = atom(1)
		local cleanedUp = false

		effect(function(cleanup)
			assert(not cleanedUp, "cleanup ran twice")
			cleanup()
			cleanedUp = true
			a()
		end)

		a(2)
		a(3)
	end)
end
