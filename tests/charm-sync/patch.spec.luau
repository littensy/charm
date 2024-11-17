local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local patch = require(ReplicatedStorage.DevPackages.CharmSync.patch)

return function()
	local function serdes(value: { [any]: any })
		return HttpService:JSONDecode(HttpService:JSONEncode(value))
	end

	it("returns a patch", function()
		local prevState = { foo = "bar", baz = "qux" }
		local nextState = { foo = "bar", baz = "quux" }
		local patches = patch.diff(prevState, nextState)

		expect(patches).to.be.ok()
		expect(patches.baz).to.equal("quux")
		expect(patches.foo).to.never.be.ok()
	end)

	it("applies a patch", function()
		local prevState = { foo = "bar", baz = "qux" }
		local patches = { baz = "quux", qaz = "qux" }
		local applied = patch.apply(prevState, patches)

		expect(applied).to.be.ok()
		expect(applied.baz).to.equal("quux")
		expect(applied.foo).to.equal("bar")
		expect(applied.qaz).to.equal("qux")
	end)

	it("allows nested patches", function()
		local prevState = { foo = { bar = "baz" } }
		local nextState = { foo = { bar = "qux" } }
		local patches = patch.diff(prevState, nextState)
		local applied = patch.apply(prevState, patches)

		expect(applied.foo.bar).to.equal("qux")
	end)

	it("preserves array density when applying", function()
		local prevState = { "a", "b", "c", "d" }
		local nextState = { ["2"] = "B", ["4"] = "D" }
		local applied = patch.apply(prevState, nextState)

		expect(applied[1]).to.equal("a")
		expect(applied[2]).to.equal("B")
		expect(applied[3]).to.equal("c")
		expect(applied[4]).to.equal("D")

		expect(applied["2"]).to.never.be.ok()
		expect(applied["4"]).to.never.be.ok()
	end)

	it("preserves array density after serdes", function()
		-- This particular change results in a patch that cannot be serialized
		-- without losing information. Charm resolves this issue internally.
		local prevState = { "a", "b", "c", "d", "e" }
		local nextState = { "A", "b", "c", "D" }

		local patches = serdes(patch.diff(prevState, nextState))
		local applied = patch.apply(prevState, patches)

		for index in next, prevState do
			expect(applied[index]).to.equal(nextState[index])
		end

		for index in next, applied do
			expect(applied[index]).to.equal(nextState[index])
		end
	end)

	it("preserves large gaps between keys", function()
		local prevState = table.create(10000, "foo")
		local nextState = table.move(prevState, 2, 9998, 2, { [1] = "bar", [9999] = "bar" })

		local start = os.clock()

		local patches = serdes(patch.diff(prevState, nextState))
		local applied = patch.apply(prevState, patches)

		assert(os.clock() - start < 10e-3, `Performance is not acceptable ({(os.clock() - start) * 1e3}ms)`)

		for index in next, prevState do
			expect(applied[index]).to.equal(nextState[index])
		end
	end)

	it("cannot preserve sparse arrays", function()
		local prevState = {}
		local nextState = { [2] = "foo" }

		local patches = serdes(patch.diff(prevState, nextState))
		local applied = patch.apply(prevState, patches)

		-- Not enough information is available to determine whether 'patches'
		-- should keep the string keys added during remote event serialization.
		expect(applied["2"]).to.be.ok()
		expect(applied[2]).to.never.be.ok()
	end)

	it("optionally fixes sparse arrays", function()
		for index in next, patch.diff({ 1, 1, 1, 1, 1 }, { 2, 1, 1, 2 }) do
			expect(index).to.be.a("string")
		end

		for index in next, patch.diff({ 1, 1, 1, 1, 1 }, { 2, 1, 1, 2 }, false) do
			expect(index).to.be.a("number")
		end
	end)
end
