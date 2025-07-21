local function handleNoYield(thread: thread, ok: boolean, ...)
	if not ok then
		return false, debug.traceback(thread, tostring((...)))
	elseif coroutine.status(thread) ~= "dead" then
		return false, debug.traceback(thread, "Attempted to yield!")
	else
		return true, ...
	end
end

local function noYield<Args..., Results...>(callback: (Args...) -> Results..., ...: Args...): (boolean, Results...)
	local thread = coroutine.create(callback)
	return handleNoYield(thread, coroutine.resume(thread, ...))
end

local function deepFreeze(object: any)
	if type(object) == "table" and not table.isfrozen(object) then
		table.freeze(object)
		for _, value in object do
			deepFreeze(value)
		end
	end
end

return {
	noYield = noYield :: typeof(pcall),
	deepFreeze = deepFreeze,
}
