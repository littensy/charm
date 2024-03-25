local atom = require(script.Parent.Parent.atom)
local derive = require(script.Parent.Parent.derive)
local store = require(script.Parent.Parent.store)

return function()
	it("memoizes the result", function()
		local calls = 0
		local a = atom(1)
		local b = atom(2)
		local double = derive(function()
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

	it("takes a custom comparator", function()
		local source = atom(1)
		local derived = derive(function()
			return source()
		end, function(prev, next)
			return next < prev
		end)
		source(2)
		expect(derived()).to.equal(2)
		source(1)
		expect(derived()).to.equal(2)
	end)

	it("can be nested", function()
		local source = atom(1)
		local double = derive(function()
			return source() * 2
		end)
		local quadruple = derive(function()
			return double() * 2
		end)
		expect(quadruple()).to.equal(4)
		source(2)
		expect(quadruple()).to.equal(8)
	end)

	it("garbage collects", function()
		-- large values coerce the garbage collector to run
		local source = atom(string.rep("x", 1e5))
		local max = 0

		local function listenersDecreased()
			local count = 0
			for _ in pairs(store.listeners[source]) do
				count += 1
			end
			max = math.max(max, count)
			return count < max
		end

		for index = 1, 500 do
			derive(function()
				return string.upper(source())
			end)
			if index % 50 == 0 then
				-- derived atoms should be collected when memory is stressed
				source(source() .. "x")
				task.wait()
			end
			if listenersDecreased() then
				return
			end
		end

		error("None of the derived atoms were collected")
	end)
end
