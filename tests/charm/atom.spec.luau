local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.DevPackages.Charm)
local atom = Charm.atom
local store = require(ReplicatedStorage.DevPackages.Charm.store)

return function()
	it("updates state", function()
		local source = atom(1)
		source(2)
		expect(source()).to.equal(2)
		source(function(x)
			return x + 1
		end)
		expect(source()).to.equal(3)
	end)

	it("calls listeners", function()
		local source = atom(1)
		local value
		local function listener()
			value = source()
		end
		store.listeners[source][listener] = true
		source(2)
		expect(value).to.equal(2)
	end)

	it("skips pending listeners", function()
		local source = atom(1)
		local outer = 0
		local inner = 0
		local function listener()
			outer += 1
			local function listener()
				inner += 1
			end
			store.listeners[source][listener] = true
		end
		store.listeners[source][listener] = true
		source(2)
		expect(outer).to.equal(1)
		expect(inner).to.equal(0)
		source(3)
		expect(outer).to.equal(2)
		expect(inner).to.equal(1)
	end)

	it("takes a custom comparator", function()
		local max = atom(1, {
			equals = function(prev, next)
				return next < prev
			end,
		})
		max(2)
		expect(max()).to.equal(2)
		max(1)
		expect(max()).to.equal(2)
		max(3)
		expect(max()).to.equal(3)
	end)
end
