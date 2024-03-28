local atom = require(script.Parent.Parent.Parent.atom)
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
end
