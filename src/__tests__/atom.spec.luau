local atom = require(script.Parent.Parent.atom)

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
		local function listener(state)
			value = state
		end
		source.listeners[listener] = true
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
			source.listeners[listener] = true
		end
		source.listeners[listener] = true
		source(2)
		expect(outer).to.equal(1)
		expect(inner).to.equal(0)
		source(3)
		expect(outer).to.equal(2)
		expect(inner).to.equal(1)
	end)

	it("can be readonly", function()
		local readonly = atom(1):readonly()

		expect(function()
			(readonly :: any)(2)
		end).to.throw()

		local writable = readonly:writable()

		writable(2)
		expect(writable()).to.equal(2)
	end)

	it("calls the setter", function()
		local source = atom(1):writable(function(_, value: number)
			return value + 1
		end)
		source(1)
		expect(source()).to.equal(2)
	end)

	it("cancels if setter returns nil", function()
		local source = atom(1):writable(function(value: number)
			return if value == 2 then nil else value
		end)
		source(2)
		expect(source()).to.equal(1)
		source(3)
		expect(source()).to.equal(3)
	end)

	it("can be memoized", function()
		local source = atom(1):memo(function(prev, next)
			return next < prev
		end)
		source(2)
		expect(source()).to.equal(2)
		source(1)
		expect(source()).to.equal(2)
	end)
end
