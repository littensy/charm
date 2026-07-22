local Charm = require("../src")
local test = require("../../../tests/test")

local effect = Charm.effect
local effectScope = Charm.effectScope
local signal = Charm.signal
local onCleanup = Charm.onCleanup

test("should not trigger after stop", function()
	local count, setCount = signal(1)

	local triggers = 0

	local stopScope = effectScope(function()
		effect(function()
			triggers += 1
			count()
		end)
		assert(triggers == 1, "did not run initially")

		setCount(2)
		assert(triggers == 2, "did not run after update")
	end)

	setCount(3)
	assert(triggers == 3, "did not run after update outside scope")
	stopScope()
	setCount(4)
	assert(triggers == 3, "ran after stop")
end)

test("should run indirect scope cleanup", function()
	local cleanups = 0
	local cleanup: () -> ()

	local stopScope = effectScope(function()
		cleanup = effectScope(function()
			onCleanup(function()
				cleanups += 1
			end)
		end)
	end)

	assert(cleanups == 0, "should not cleanup immediately")
	stopScope()
	assert(cleanups == 1, "should cleanup from parent dispose")
	cleanup()
	assert(cleanups == 1, "should skip redundant dispose")
end)

test("should run indirect effect cleanup", function()
	local cleanups = 0
	local a, setA = signal(false)

	local stopScope = effectScope(function()
		effect(function()
			a()
			onCleanup(function()
				cleanups += 1
			end)
		end)
	end)

	assert(cleanups == 0, "should not cleanup immediately")
	setA(true)
	assert(cleanups == 1, "should cleanup once")
	stopScope()
	assert(cleanups == 2, "should cleanup after outer dispose")
	setA(false)
	assert(cleanups == 2, "should not cleanup after update")
end)

test("should dispose inner effects if created in an effect", function()
	local source, setSource = signal(1)
	local triggers = 0
	local dispose: () -> ()

	effect(function()
		dispose = effectScope(function()
			effect(function()
				source()
				triggers += 1
			end)
		end)
		assert(triggers == 1, "did not run initially")
	end)

	setSource(2)
	assert(triggers == 2, "did not run after update")
	dispose()
	setSource(3)
	assert(triggers == 2, "ran after dispose")
end)

test("should dispose child effects in reverse order", function()
	local order: { number } = {}
	local stopScope = effectScope(function()
		for i = 1, 3 do
			effect(function()
				return function()
					table.insert(order, i)
				end
			end)
		end
	end)

	stopScope()
	assert(table.concat(order) == "321", `bad dispose order: {table.concat(order)}`)
end)

test("should dispose nested effects deepest first", function()
	local order: { string } = {}
	local stopScope = effectScope(function()
		effect(function()
			effect(function()
				return function()
					table.insert(order, "grandchild")
				end
			end)
			return function()
				table.insert(order, "child")
			end
		end)
	end)

	stopScope()
	assert(table.concat(order, ", ") == "grandchild, child", `bad dispose order: {table.concat(order, ", ")}`)
end)

test("should cleanup an intermediate scope before its parent effect", function()
	local order: { string } = {}
	local src, setSrc = signal(false)

	effect(function()
		src()
		table.insert(order, "outer run")
		effectScope(function()
			effect(function()
				table.insert(order, "inner run")
				return function()
					table.insert(order, "inner cleanup")
				end
			end)
		end)
		return function()
			table.insert(order, "outer cleanup")
		end
	end)

	table.clear(order)
	setSrc(true)
	assert(
		table.concat(order, ", ") == "inner cleanup, outer cleanup, outer run, inner run",
		`bad rerun order: {table.concat(order, ", ")}`
	)
end)

return {}
