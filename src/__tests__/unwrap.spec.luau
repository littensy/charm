local atom = require(script.Parent.Parent.atom)
local peek = require(script.Parent.Parent.peek)
local store = require(script.Parent.Parent.store)

return function()
	it("calls an atom without capturing it", function()
		local a, b, c = atom(1), atom(1), atom(1)
		local captured, result = store.capture(function()
			return a() + peek(b) + c()
		end)
		expect(captured[a]).to.be.ok()
		expect(captured[b]).to.never.be.ok()
		expect(captured[c]).to.be.ok()
		expect(result).to.equal(3)
	end)

	it("passes through arguments", function()
		expect(peek(1)).to.equal(1)
		expect(peek(function()
			return 1
		end)).to.equal(1)
	end)
end
