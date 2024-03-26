local atom = require(script.Parent.Parent.Parent.atom)
local useSetAtom = require(script.Parent.Parent.Parent.react.useSetAtom)
local renderHook = require(script.Parent.helpers.renderHook)

return function()
	it("sets atom state", function()
		local source = atom(0)
		local hook = renderHook(function()
			return useSetAtom(source)
		end)
		expect(hook.result).to.be.a("function")
		hook.result(1)
		expect(source()).to.equal(1)
	end)

	it("returns a stable function", function()
		local source = atom(0)
		local hook = renderHook(function()
			return useSetAtom(source)
		end)
		local fn = hook.result
		hook.rerender()
		expect(hook.result).to.equal(fn)
	end)

	it("memoizes the function", function()
		local hook = renderHook(function(props)
			return useSetAtom(props.source)
		end, { source = atom(0) })
		local fn = hook.result
		hook.rerender({ source = atom(1) })
		expect(hook.result).to.never.equal(fn)
	end)
end
