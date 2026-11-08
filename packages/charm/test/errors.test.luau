--!optimize 1

local Charm = require("../src")
local test = require("../../../tests/test")

test("should disallow yielding", function()
	local success = pcall(function()
		Charm.effectScope(function()
			coroutine.yield()
		end)
	end)
	assert(not success, "should error on yield")
end)

for _, batched in { false, true } do
	test(`should run every queued effect before rethrowing errors (batched: {batched})`, function()
		local src = Charm.atom(0)
		local seen = 0

		Charm.effect(function()
			if src() == 1 then
				error("first effect failed", 0)
			end
		end)
		Charm.effect(function()
			if src() == 1 then
				error("second effect failed", 0)
			end
		end)
		Charm.effect(function()
			seen = src()
		end)

		local success, err = pcall(function()
			if batched then
				Charm.batch(function()
					src(1)
				end)
			else
				src(1)
			end
		end)

		assert(seen == 1, "should run the sibling effect before rethrowing")
		assert(not success, "should rethrow effect errors to the writer")
		assert(type(err) == "string", "should combine effect errors into a string")
		assert(string.find(err, "first effect failed"), `missing first error: {err}`)
		assert(string.find(err, "second effect failed"), `missing second error: {err}`)

		src(2)
		assert(seen == 2, "should run effects on the next write")
	end)
end

test("should not retry a failed recursive effect in the same flush", function()
	local src = Charm.atom(0)
	local runs = 0
	local seen = 0

	Charm.effect(function()
		local value = src()
		if value > 0 and value < 4 then
			runs += 1
			src(value + 1)
			error("recursive effect failed", 0)
		end
	end)
	Charm.effect(function()
		seen = src()
	end)

	local success, err = pcall(function()
		src(1)
	end)
	assert(not success and string.find(tostring(err), "recursive effect failed"), `bad error: {err}`)
	assert(runs == 1, "should not retry the failed effect in the same flush")
	assert(seen == 2, "should run the sibling with the latest value")

	src(4)
	assert(seen == 4, "should run effects on the next write")
end)

test("should recover a skipped failed effect through a computed dependency", function()
	local trigger = Charm.atom(0)
	local src = Charm.atom(0)
	local value = Charm.computed(function()
		return src()
	end)
	local runs = 0
	local seen = 0
	local fail = true

	Charm.effect(function()
		local current = trigger()
		seen = value()
		runs += 1
		if current == 1 and fail then
			error("effect failed", 0)
		end
	end)
	Charm.effect(function()
		if trigger() == 1 then
			src(10)
		end
	end)

	assert(not pcall(trigger, 1), "should report the failed effect")
	assert(runs == 2 and seen == 0, "should skip the requeued failed effect")
	fail = false
	for nextValue = 11, 13 do
		src(nextValue)
		assert(seen == nextValue, "should recover through the computed dependency")
		assert(runs == nextValue - 8, "should run once per dependency write")
	end
end)

test("should settle every computed dependency of a skipped failed effect", function()
	local trigger = Charm.atom(0)
	local first = Charm.atom(0)
	local second = Charm.atom(0)
	local firstValue = Charm.computed(function()
		return first()
	end)
	local secondValue = Charm.computed(function()
		return second()
	end)
	local fail = true
	local seenFirst = 0
	local seenSecond = 0
	local runs = 0

	Charm.effect(function()
		local current = trigger()
		seenFirst, seenSecond = firstValue(), secondValue()
		runs += 1
		if current == 1 and fail then
			error("effect failed", 0)
		end
	end)
	Charm.effect(function()
		if trigger() == 1 then
			first(10)
			second(20)
		end
	end)

	assert(not pcall(trigger, 1), "should report the failed effect")
	assert(runs == 2, "should skip the requeued failed effect")
	fail = false
	second(21)
	assert(runs == 3 and seenFirst == 10 and seenSecond == 21, "should recover through the second computed")
	first(11)
	assert(runs == 4 and seenFirst == 11, "should also recover through the first computed")
end)

test("should keep a skipped failed effect isolated until its dependency changes", function()
	local src = Charm.atom(0)
	local other = Charm.atom(0)
	local runs = 0
	local seen = 0
	local otherSeen = 0

	Charm.effect(function()
		local value = src()
		runs += 1
		if value == 1 then
			src(2)
			error("recursive effect failed", 0)
		end
	end)
	Charm.effect(function()
		seen = src()
	end)
	Charm.effect(function()
		otherSeen = other()
	end)

	assert(not pcall(src, 1), "should report the failed effect")
	assert(runs == 2 and seen == 2, "should skip only the requeued failed effect")
	other(1)
	assert(otherSeen == 1, "should flush the unrelated effect")
	assert(runs == 2 and seen == 2, "should not retry on an unrelated write")
	src(4)
	assert(runs == 3 and seen == 4, "should recover on its own dependency write")
end)

test("should recover a skipped failed effect after another reader settles its computed", function()
	local trigger = Charm.atom(0)
	local src = Charm.atom(0)
	local reached = Charm.computed(function()
		return src() >= 10
	end)
	local fail = true
	local seen = false
	local readerSeen = false

	Charm.effect(function()
		readerSeen = reached()
	end)
	Charm.effect(function()
		local value = trigger()
		seen = reached()
		if value == 1 and fail then
			error("reader effect failed", 0)
		end
	end)
	Charm.effect(function()
		if trigger() == 1 then
			src(10)
		end
	end)

	assert(not pcall(trigger, 1), "should report the failed effect")
	assert(readerSeen and not seen, "the other reader should settle the computed first")
	fail = false
	src(11)
	assert(seen, "should rerun the failed effect for the change it missed")
end)

test.describe("non-strict flush errors", function()
	local previousStrict = Charm.flags.strict
	test.beforeEach(function()
		previousStrict = Charm.flags.strict
		Charm.flags.strict = false
	end)
	test.afterEach(function()
		Charm.flags.strict = previousStrict
	end)

	test("should rethrow one table error unchanged", function()
		local src = Charm.atom(0)
		local payload = {}
		local seen = 0
		Charm.effect(function()
			if src() == 1 then
				error(payload, 0)
			end
		end)
		Charm.effect(function()
			seen = src()
		end)

		local success, err = pcall(function()
			src(1)
		end)
		assert(not success and err == payload, "should preserve the original error value")
		assert(seen == 1, "should finish the queue before rethrowing")
		src(2)
		assert(seen == 2, "should flush the next write")
	end)

	test("should combine two errors in queue order", function()
		local src = Charm.atom(0)
		for _, message in { "first failure", "second failure" } do
			Charm.effect(function()
				if src() == 1 then
					error(message, 0)
				end
			end)
		end

		local success, err = pcall(function()
			src(1)
		end)
		assert(not success, "should report both errors")
		assert(
			err == "Errors occurred during effect execution:\n\nfirst failure\n\nsecond failure",
			"should combine errors in queue order"
		)
	end)

	test("should finish and recover when error conversion throws", function()
		local src = Charm.atom(0)
		local seen = 0
		local payload = setmetatable({}, {
			__tostring = function(): string
				error("error conversion failed", 0)
			end,
		})
		Charm.effect(function()
			if src() == 1 then
				error(payload, 0)
			end
		end)
		Charm.effect(function()
			if src() == 1 then
				error("second failure", 0)
			end
		end)
		Charm.effect(function()
			seen = src()
		end)

		local success, err = pcall(function()
			src(1)
		end)
		assert(not success, "should report the errors")
		assert(seen == 1, "should finish the queue before converting errors")
		assert(
			err
				== "Errors occurred during effect execution:\n\n<error could not be converted to a string>\n\nsecond failure",
			"should safely combine errors"
		)
		src(2)
		assert(seen == 2, "should flush the next write")
		local fresh = Charm.atom(0)
		local freshSeen = 0
		Charm.effect(function()
			freshSeen = fresh()
		end)
		fresh(5)
		assert(freshSeen == 5, "should flush a new unrelated effect")
	end)
end)

test.describe("traceback", function()
	local DEFAULT_ERROR = "Test error"

	local function fail(message: string?)
		error(message or DEFAULT_ERROR, 0)
	end

	local function indirectError(message: string?)
		fail(message)
	end

	local function assertStackTrace(err: unknown, expectation: string?)
		expectation = expectation or DEFAULT_ERROR
		assert(type(err) == "string", "Expected error to be a string")
		assert(string.find(err, expectation), `Expected error message to be "{expectation}", got: {err}`)
		assert(string.find(err, "fail"), `Expected stack trace to contain fail, got: {err}`)
		assert(string.find(err, "indirectError"), `Expected stack trace to contain indirectError, got: {err}`)
	end

	test("signal update", function()
		local _, err = pcall(function()
			local _, setSrc = Charm.signal(0)
			setSrc(function()
				indirectError()
				return 1
			end)
		end)
		assertStackTrace(err)
	end)

	test("atom update", function()
		local _, err = pcall(function()
			local src = Charm.atom(0)
			src(function()
				indirectError()
				return 1
			end)
		end)
		assertStackTrace(err)
	end)

	test("computed", function()
		local _, err = pcall(function()
			local src = Charm.computed(function()
				indirectError()
			end)
			src()
		end)
		assertStackTrace(err)
	end)

	test("effect init", function()
		local _, err = pcall(function()
			Charm.effect(function()
				indirectError()
			end)
		end)
		assertStackTrace(err)
	end)

	test("effect run", function()
		local _, err = pcall(function()
			local src, setSrc = Charm.signal(0)
			Charm.effect(function()
				if src() == 1 then
					indirectError()
				end
			end)
			setSrc(1)
		end)
		assertStackTrace(err)
	end)

	test("effect cleanups", function()
		local _, err = pcall(function()
			local dispose = Charm.effect(function()
				Charm.onCleanup(function()
					indirectError("onCleanup")
				end)
				return function()
					indirectError("returned cleanup")
				end
			end)
			dispose()
		end)
		assertStackTrace(err, "onCleanup")
		assertStackTrace(err, "returned cleanup")
	end)

	test("trigger", function()
		local _, err = pcall(function()
			Charm.trigger(function()
				indirectError()
			end)
		end)
		assertStackTrace(err)
	end)

	test("untracked", function()
		local _, err = pcall(function()
			Charm.effectScope(function()
				Charm.untracked(function()
					indirectError()
				end)
			end)
		end)
		assertStackTrace(err)
	end)

	test("batch", function()
		local _, err = pcall(function()
			Charm.batch(function()
				indirectError()
			end)
		end)
		assertStackTrace(err)
	end)

	test("subscribe getter", function()
		local _, err = pcall(function()
			Charm.subscribe(function()
				indirectError()
			end, function() end)
		end)
		assertStackTrace(err)
	end)

	test("subscribe callback", function()
		local _, err = pcall(function()
			local src, setSrc = Charm.signal(0)
			Charm.subscribe(src, function()
				indirectError()
			end)
			setSrc(1)
		end)
		assertStackTrace(err)
	end)

	test("listen getter", function()
		local _, err = pcall(function()
			Charm.listen(function()
				indirectError()
			end, function() end)
		end)
		assertStackTrace(err)
	end)

	test("listen callback", function()
		local _, err = pcall(function()
			local src, setSrc = Charm.signal(0)
			Charm.listen(src, function()
				indirectError()
			end)
			setSrc(1)
		end)
		assertStackTrace(err)
	end)

	test("mapped getter", function()
		local _, err = pcall(function()
			local src = Charm.mapped(function()
				indirectError()
				return { 1 }
			end, function()
				return 1
			end)
			src()
		end)
		assertStackTrace(err)
	end)

	test("mapped transform", function()
		local _, err = pcall(function()
			local src = Charm.mapped(function()
				return { 1 }
			end, function()
				indirectError()
				return 1
			end)
			src()
		end)
		assertStackTrace(err)
	end)
end)

return {}
