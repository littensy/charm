local signals = require("../../src/signals")
local suite = require("@test/suite")

local computed = signals.computed
local effect = signals.effect
local signal = signals.signal
local describe = suite.describe
local test = suite.test

--[[
	Tests adopted with thanks from preact-signals implementation at
	https://github.com/preactjs/signals/blob/main/packages/core/test/signal.test.tsx

	The MIT License (MIT)

	Copyright (c) 2022-present Preact Team

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE
]]

describe("graph updates", function()
	test("should drop A->B->A updates", function()
		--     A
		--   / |
		--  B  | <- Looks like a flag doesn't it? :D
		--   \ |
		--     C
		--     |
		--     D
		local a, setA = signal(2)

		local b = computed(function()
			return a() - 1
		end)
		local c = computed(function()
			return a() + b()
		end)

		local computeCalls = 0
		local compute = function()
			computeCalls += 1
			return "d: " .. c()
		end
		local d = computed(compute)

		-- Trigger read
		assert(d() == "d: 3", "d should be 3")
		assert(computeCalls == 1, "compute should be called once")
		computeCalls = 0

		setA(4)
		d()
		assert(computeCalls == 1, "compute should drop update")
	end)

	test("should only update every signal once (diamond graph)", function()
		-- In this scenario "D" should only update once when "A" receives
		-- an update. This is sometimes referred to as the "diamond" scenario.
		--     A
		--   /   \
		--  B     C
		--   \   /
		--     D

		local a, setA = signal("a")
		local b = computed(function()
			return a()
		end)
		local c = computed(function()
			return a()
		end)

		local spyCalls = 0
		local spy = function()
			spyCalls += 1
			return b() .. " " .. c()
		end
		local d = computed(spy)

		assert(d() == "a a", "d should be 'a a'")
		assert(spyCalls == 1, "compute should be called once")

		setA("aa")
		assert(d() == "aa aa", "d should be 'aa aa'")
		assert(spyCalls == 2, "compute should be called only twice")
	end)

	test("should only update every signal once (diamond graph + tail)", function()
		-- "E" will be likely updated twice if our mark+sweep logic is buggy.
		--     A
		--   /   \
		--  B     C
		--   \   /
		--     D
		--     |
		--     E

		local a, setA = signal("a")
		local b = computed(function()
			return a()
		end)
		local c = computed(function()
			return a()
		end)

		local d = computed(function()
			return b() .. " " .. c()
		end)

		local spyCalls = 0
		local spy = function()
			spyCalls += 1
			return d()
		end
		local e = computed(spy)

		assert(e() == "a a", "e should be 'a a'")
		assert(spyCalls == 1, "compute should be called once")

		setA("aa")
		assert(e() == "aa aa", "e should be 'aa aa'")
		assert(spyCalls == 2, "compute should be called only twice")
	end)

	test("should bail out if result is the same", function()
		-- Bail out if value of "B" never changes
		-- A->B->C
		local a, setA = signal("a")
		local b = computed(function()
			a()
			return "foo"
		end)

		local spyCalls = 0
		local spy = function()
			spyCalls += 1
			return b()
		end
		local c = computed(spy)

		assert(c() == "foo", "c should be 'foo'")
		assert(spyCalls == 1, "compute should be called once")

		setA("aa")
		assert(c() == "foo", "c should be 'foo'")
		assert(spyCalls == 1, "compute should bail out")
	end)

	test("should only update every signal once (jagged diamond graph + tails)", function()
		-- "F" and "G" will be likely updated twice if our mark+sweep logic is buggy.
		--     A
		--   /   \
		--  B     C
		--  |     |
		--  |     D
		--   \   /
		--     E
		--   /   \
		--  F     G
		local a, setA = signal("a")

		local b = computed(function()
			return a()
		end)
		local c = computed(function()
			return a()
		end)

		local d = computed(function()
			return c()
		end)

		local eSpyCalls = 0
		local eSpyTime = 0
		local eSpy = function()
			eSpyCalls += 1
			eSpyTime = os.clock()
			return b() .. " " .. d()
		end
		local e = computed(eSpy)

		local fSpyCalls = 0
		local fSpyTime = 0
		local fSpy = function()
			fSpyCalls += 1
			fSpyTime = os.clock()
			return e()
		end
		local f = computed(fSpy)
		local gSpyCalls = 0
		local gSpyTime = 0
		local gSpy = function()
			gSpyCalls += 1
			gSpyTime = os.clock()
			return e()
		end
		local g = computed(gSpy)

		assert(f() == "a a", "f should be 'a a'")
		assert(fSpyCalls == 1, "f should be called once")

		assert(g() == "a a", "g should be 'a a'")
		assert(gSpyCalls == 1, "g should be called once")

		eSpyCalls, eSpyTime = 0, 0
		fSpyCalls, fSpyTime = 0, 0
		gSpyCalls, gSpyTime = 0, 0

		setA("b")

		assert(e() == "b b", "e should be 'b b'")
		assert(eSpyCalls == 1, "e should run once after update")

		assert(f() == "b b", "f should be 'b b'")
		assert(fSpyCalls == 1, "f should run once after update")

		assert(g() == "b b", "g should be 'b b'")
		assert(gSpyCalls == 1, "g should run once after update")

		eSpyCalls, eSpyTime = 0, 0
		fSpyCalls, fSpyTime = 0, 0
		gSpyCalls, gSpyTime = 0, 0

		setA("c")

		assert(e() == "c c", "e should be 'c c'")
		assert(eSpyCalls == 1, "e should run once after update")

		assert(f() == "c c", "f should be 'c c'")
		assert(fSpyCalls == 1, "f should run once after update")

		assert(g() == "c c", "g should be 'c c'")
		assert(gSpyCalls == 1, "g should run once after update")

		-- top to bottom
		assert(eSpyTime < fSpyTime, "e should be called before f")
		-- left to right
		assert(eSpyTime < gSpyTime, "e should be called before g")
	end)

	test("should only subscribe to signals listened to", function()
		--    *A
		--   /   \
		-- *B     C <- we don't listen to C
		local a, setA = signal("a")

		local b = computed(function()
			return a()
		end)
		local spyCalls = 0
		local spy = function()
			spyCalls += 1
			return a()
		end
		computed(spy)

		assert(b() == "a", "b should be 'a'")
		assert(spyCalls == 0, "compute should not run")

		setA("aa")
		assert(b() == "aa", "b should be 'aa'")
		assert(spyCalls == 0, "compute should not run")
	end)

	test("should only subscribe to signals listened to II", function()
		-- Here both "B" and "C" are active in the beginning, but
		-- "B" becomes inactive later. At that point it should
		-- not receive any updates anymore.
		--    *A
		--   /   \
		-- *B     D <- we don't listen to C
		--  |
		-- *C
		local a, setA = signal("a")
		local spyBCalls = 0
		local spyB = function()
			spyBCalls += 1
			return a()
		end
		local b = computed(spyB)

		local spyCCalls = 0
		local spyC = function()
			spyCCalls += 1
			return b()
		end
		local c = computed(spyC)

		local d = computed(function()
			return a()
		end)

		local result = ""
		local unsub = effect(function()
			result = c()
		end)

		assert(result == "a", "result should be 'a'")
		assert(d() == "a", "d should be 'a'")

		spyBCalls = 0
		spyCCalls = 0
		unsub()

		setA("aa")

		assert(spyBCalls == 0, "b should not run")
		assert(spyCCalls == 0, "c should not run")
		assert(d() == "aa", "d should be 'aa'")
	end)

	test("should ensure subs update even if one dep unmarks it", function()
		-- In this scenario "C" always returns the same value. When "A"
		-- changes, "B" will update, then "C" at which point its update
		-- to "D" will be unmarked. But "D" must still update because
		-- "B" marked it. If "D" isn't updated, then we have a bug.
		--     A
		--   /   \
		--  B     *C <- returns same value every time
		--   \   /
		--     D
		local a, setA = signal("a")
		local b = computed(function()
			return a()
		end)
		local c = computed(function()
			a()
			return "c"
		end)
		local spyResult: string?
		local spy = function()
			spyResult = b() .. " " .. c()
			return spyResult
		end
		local d = computed(spy)

		assert(d() == "a c", "d should be 'a c'")
		spyResult = nil

		setA("aa")
		d()
		assert(spyResult == "aa c", "d should have returned 'aa c'")
	end)

	test("should ensure subs update even if two deps unmark it", function()
		-- In this scenario both "C" and "D" always return the same
		-- value. But "E" must still update because "A" marked it.
		-- If "E" isn't updated, then we have a bug.
		--     A
		--   / | \
		--  B *C *D
		--   \ | /
		--     E
		local a, setA = signal("a")
		local b = computed(function()
			return a()
		end)
		local c = computed(function()
			a()
			return "c"
		end)
		local d = computed(function()
			a()
			return "d"
		end)
		local spyResult: string?
		local spy = function()
			spyResult = b() .. " " .. c() .. " " .. d()
			return spyResult
		end
		local e = computed(spy)

		assert(e() == "a c d", "e should be 'a c d'")
		spyResult = nil

		setA("aa")
		e()
		assert(spyResult == "aa c d", "e should have returned 'aa c d'")
	end)

	test("should support lazy branches", function()
		local a, setA = signal(0)
		local b = computed(function()
			return a()
		end)
		local c = computed(function()
			return if a() > 0 then a() else b()
		end)

		assert(c() == 0, "c should be 0")
		setA(1)
		assert(c() == 1, "c should be 1")

		setA(0)
		assert(c() == 0, "c should be 0 again")
	end)

	test("should not update a sub if all deps unmark it", function()
		-- In this scenario "B" and "C" always return the same value. When "A"
		-- changes, "D" should not update.
		--     A
		--   /   \
		-- *B     *C
		--   \   /
		--     D
		local a, setA = signal("a")
		local b = computed(function()
			a()
			return "b"
		end)
		local c = computed(function()
			a()
			return "c"
		end)
		local spyCalls = 0
		local spy = function()
			spyCalls += 1
			return b() .. " " .. c()
		end
		local d = computed(spy)

		assert(d() == "b c", "d should be 'b c'")
		spyCalls = 0

		setA("aa")
		assert(spyCalls == 0, "d should not run")
	end)
end)

describe("error handling", function()
	test("should keep graph consistent on errors during activation", function()
		local a, setA = signal(0)
		local b = computed(function()
			error("fail")
		end)
		local c = computed(function()
			return a()
		end)

		local success, result = pcall(function()
			b()
		end)
		assert(not success, "should throw")
		assert(string.match(result, "fail"), "should throw fail")

		setA(1)
		assert(c() == 1, "c should recover and return 1")
	end)

	test("should keep graph consistent on errors in computeds", function()
		local a, setA = signal(0)
		local b = computed(function()
			if a() == 1 then
				error("fail")
			end
			return a()
		end)
		local c = computed(function()
			return b()
		end)

		assert(c() == 0, "c should be 0")

		setA(1)
		local success, result = pcall(function()
			b()
		end)
		assert(not success, "should throw")
		assert(string.match(result, "fail"), "should throw fail")

		setA(2)
		assert(c() == 2, "c should recover and return 2")
	end)
end)

return {}
