local atom = require(script.Parent.Parent.atom)
local store = require(script.Parent.Parent.store)
local unwrap = require(script.Parent.Parent.unwrap)

return function()
	it("calls an atom without capturing it", function()
		local a, b, c = atom(1), atom(1), atom(1)
		local captured, result = store.capture(function()
			return a() + unwrap(b) + c()
		end)
		expect(captured[a]).to.be.ok()
		expect(captured[b]).to.never.be.ok()
		expect(captured[c]).to.be.ok()
		expect(result).to.equal(3)
	end)

	it("passes through arguments", function()
		expect(unwrap(1)).to.equal(1)
		expect(unwrap(function()
			return 1
		end)).to.equal(1)
	end)
end
