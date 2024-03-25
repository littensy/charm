local atom = require(script.Parent.Parent.atom)
local store = require(script.Parent.Parent.store)

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
end
