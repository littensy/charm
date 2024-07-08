local atom = require(script.Parent.Parent.Parent.atom)
local subscribe = require(script.Parent.Parent.Parent.subscribe)
local sync = require(script.Parent.Parent.Parent.sync)

return function()
	it("syncs state payload", function()
		local a = atom(1)
		local client = sync.client({ atoms = { a = a } })

		client:sync({
			type = "init",
			data = { a = 2 },
		})

		expect(a()).to.equal(2)
	end)

	it("syncs state patch", function()
		local a = atom({ b = 1, c = 2 })
		local previous = a()
		local client = sync.client({ atoms = { a = a } })

		client:sync({
			type = "patch",
			data = { a = { b = 3 } },
		})

		expect(a()).to.never.equal(previous)
		expect(a().b).to.equal(3)
		expect(a().c).to.equal(2)
	end)

	it("fixes sparse array patches", function()
		local a = atom({ 1 })
		local client = sync.client({ atoms = { a = a } })

		-- This patch would be the result of a diff between { 1 } and { 1, 2 } that
		-- was JSON-serialized and deserialized. The client should be able to catch
		-- this and convert the string key back to a number.
		client:sync({
			type = "patch",
			data = { a = { ["2"] = 2 } },
		})

		expect(a()["2" :: any]).to.never.be.ok()
		expect(a()[2]).to.equal(2)
	end)

	it("applies multiple patches", function()
		local a = atom(1)
		local client = sync.client({ atoms = { a = a } })
		local calls = {}

		subscribe(a, function(value)
			table.insert(calls, value)
		end)

		client:sync({
			type = "patch",
			data = { a = 2 },
		}, {
			type = "patch",
			data = { a = 3 },
		})

		expect(a()).to.equal(3)
		expect(calls[1]).to.equal(2)
		expect(calls[2]).to.equal(3)
	end)
end
