local function handleNoYield(thread: thread, ok: boolean, ...)
	if not ok then
		return false, debug.traceback(thread, tostring((...)))
	end

	if coroutine.status(thread) ~= "dead" then
		return false, debug.traceback(thread, "Attempted to yield!")
	end

	return true, ...
end

local function noYield<Args..., Results...>(callback: (Args...) -> Results..., ...: Args...): (boolean, Results...)
	local thread = coroutine.create(callback)
	return handleNoYield(thread, coroutine.resume(thread, ...))
end

-- To eliminate the overhead of noYield returning callback(...) in production,
-- replace it with pcall to simulate the same behavior.
return if _G.__DEV__ then noYield else pcall :: never
