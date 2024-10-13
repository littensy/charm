local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.DevPackages.Charm)
local atom = Charm.atom
local capture = Charm.capture
local peek = Charm.peek

return function()
	it("calls an atom without capturing it", function()
		local a, b, c = atom(1), atom(1), atom(1)
		local deps, result = capture(function()
			return a() + peek(b) + c()
		end)
		expect(deps[a]).to.be.ok()
		expect(deps[b]).to.never.be.ok()
		expect(deps[c]).to.be.ok()
		expect(result).to.equal(3)
	end)

	it("passes through arguments", function()
		expect(peek(1)).to.equal(1)
		expect(peek(function()
			return 1
		end)).to.equal(1)
	end)
end
