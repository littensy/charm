local ReplicatedStorage = game:GetService("ReplicatedStorage")

local packets = require(ReplicatedStorage.DevPackages.CharmSync.packets)

return function()
	it("creates a packet", function()
		local prevState = { foo = "bar", baz = "qux" }
		local nextState = { foo = "bar", baz = "quux" }
		local results = packets.diff(prevState, nextState)

		expect(#results).to.equal(1)
		expect(table.concat(results[1].path, "/")).to.equal("baz")
		expect(results[1].data).to.equal("quux")
	end)

	it("applies a packet", function()
		local prevState = { foo = "bar", baz = "qux" }
		local packet: packets.Packet = { path = { "baz" }, data = "quux" }
		local nextState = packets.apply(prevState, { packet })

		expect(nextState.baz).to.equal("quux")
		expect(nextState.foo).to.equal("bar")
	end)

	it("applies nested packets", function()
		local prevState = { foo = { bar = "baz" } }
		local nextState = { foo = { bar = "qux" } }

		local results = packets.diff(prevState, nextState)
		local applied = packets.apply(prevState, results)

		expect(prevState.foo.bar).to.equal("baz")
		expect(applied.foo.bar).to.equal("qux")
	end)

	it("only copies changed tables", function()
		local prevState = { foo = { bar = "baz" }, baz = { qux = "quux" } }
		local nextState = { foo = { bar = "qux" }, baz = table.clone(prevState.baz) }

		local results = packets.diff(prevState, nextState)
		local applied = packets.apply(prevState, results)

		expect(applied).to.never.equal(prevState)
		expect(applied.foo).to.never.equal(prevState.foo)
		expect(applied.foo.bar).to.equal("qux")
		expect(applied.baz).to.equal(prevState.baz)
	end)

	it("excludes unchanged tables", function()
		local prevState = { foo = { bar = "baz" }, baz = { qux = "quux" } }
		local nextState = { foo = { bar = "qux" }, baz = table.clone(prevState.baz) }
		local results = packets.diff(prevState, nextState)

		expect(#results).to.equal(1)
		expect(table.concat(results[1].path, "/")).to.equal("foo/bar")
		expect(results[1].data).to.equal("qux")
	end)

	it("overwrites cleared tables", function()
		local prevState = { foo = { 1, 2, 3 } }
		local nextState = { foo = {} }
		local results = packets.diff(prevState, nextState)

		expect(#results).to.equal(1)
		expect(table.concat(results[1].path, "/")).to.equal("foo")
		expect(#results[1].data).to.equal(0)
	end)
end
