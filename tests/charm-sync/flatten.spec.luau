local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.DevPackages.charm)
local atom = Charm.atom
local CharmSync = require(ReplicatedStorage.DevPackages["charm-sync"])
local flatten = CharmSync.flatten

return function()
	it("flattens atoms", function()
		local input = {
			a = atom(0),
			b = { c = atom(0) },
			d = { e = { f = atom(0) } },
		}
		local result = flatten(input)

		expect(result.a).to.equal(input.a)
		expect(result["b/c"]).to.equal(input.b.c)
		expect(result["d/e/f"]).to.equal(input.d.e.f)

		expect(result.b).to.never.be.ok()
		expect(result.d).to.never.be.ok()
	end)
end
