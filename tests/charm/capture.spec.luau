local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.DevPackages.Charm)
local atom = Charm.atom
local subscribe = Charm.subscribe
local store = require(ReplicatedStorage.DevPackages.Charm.store)

return function()
	it("gracefully handles yielding", function()
		expect(function()
			store.capture(function()
				task.wait(10)
				return 1
			end)
		end).to.throw()
	end)

	it("captures atoms from a function", function()
		local a, b, c = atom(1), atom(1), atom(2)
		local deps, result = store.capture(function()
			return a() + b()
		end)
		expect(deps[a]).to.be.ok()
		expect(deps[b]).to.be.ok()
		expect(deps[c]).to.never.be.ok()
		expect(result).to.equal(2)
	end)

	it("captures an atom by itself", function()
		local a = atom(1)
		local deps, result = store.capture(a)
		expect(deps[a]).to.be.ok()
		expect(result).to.equal(1)
	end)

	it("skips atoms in inner capture calls", function()
		local a = atom(1)
		local b = atom(1)
		local inner
		local outer = store.capture(function()
			inner = store.capture(function()
				return b()
			end)
			return a()
		end)

		assert(outer[a], "outer did not capture a")
		assert(outer[b] == nil, "outer captured b")
		assert(inner[a] == nil, "inner captured a")
		assert(inner[b], "inner did not capture b")
	end)

	it("should not capture notified dependents", function()
		local state = atom(1)

		subscribe(state, function() end)

		local deps = store.capture(function()
			return state(2)
		end)

		expect(deps[state]).to.never.be.ok()
	end)
end
