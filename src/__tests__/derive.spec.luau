local atom = require(script.Parent.Parent.atom)
local derive = require(script.Parent.Parent.derive)

return function()
	it("derives from dependencies", function()
		local a = atom(1)
		local b = atom(2)
		local sum = derive(a, b, function(a: number, b: number)
			return a + b
		end)
		expect(sum()).to.equal(3)
		a(2)
		expect(sum()).to.equal(4)
		b(3)
		expect(sum()).to.equal(5)
		expect(function()
			(sum :: any)(2)
		end).to.throw()
	end)

	it("memoizes the result", function()
		local calls = 0
		local source = atom(1)
		local double = derive(source, function(value: number)
			calls += 1
			return value * 2
		end)
		expect(calls).to.equal(1)
		source(1)
		expect(calls).to.equal(1)
		source(2)
		expect(calls).to.equal(2)
		double()
		expect(calls).to.equal(2)
	end)

	it("can be a dependency", function()
		local source = atom(1)
		local double = derive(source, function(value: number)
			return value * 2
		end)
		local quadruple = derive(double, function(value: number)
			return value * 2
		end)
		expect(quadruple()).to.equal(4)
		source(2)
		expect(quadruple()).to.equal(8)
	end)

	it("allows custom setter", function()
		local source = atom(1)
		local double = derive(source, function(value: number)
			return value * 2
		end):writable(function(update: number)
			source(update / 2)
		end)
		double(4)
		expect(source()).to.equal(2)
		expect(double()).to.equal(4)
	end)

	it("garbage collects", function()
		-- large values coerce the garbage collector to run
		local source = atom(string.rep("x", 1e5))
		local max = 0

		local function listenersDecreased()
			local count = 0
			for _ in source.listeners do
				count += 1
			end
			max = math.max(max, count)
			return count < max
		end

		for index = 1, 500 do
			derive(source, function(value)
				return string.upper(value)
			end)
			if index % 50 == 0 then
				-- derived atoms check if they are collected when they are updated
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
