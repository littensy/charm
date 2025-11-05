local function noYieldHandler(thread: thread, ok: boolean, ...): (boolean, ...any)
	if ok and coroutine.status(thread) == "dead" then
		return true, ...
	elseif not ok then
		return false, debug.traceback(thread, tostring((...)))
	else
		return false, debug.traceback(thread, "Attempted to yield!")
	end
end

local function noYield<Args..., Results...>(callback: (Args...) -> Results..., ...: Args...): (boolean, Results...)
	local thread = coroutine.create(callback)
	return noYieldHandler(thread, coroutine.resume(thread, ...))
end

local function deepFreeze(object: any)
	if type(object) == "table" and not table.isfrozen(object) and getmetatable(object) == nil then
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
