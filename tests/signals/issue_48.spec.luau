local test = require("../suite").test
local signals = require("../charm").signals

local computed = signals.computed
local effect = signals.effect
local pauseTracking = signals.pauseTracking
local resumeTracking = signals.resumeTracking
local signal = signals.signal

type ReactionOptions<T = unknown> = {
	fireImmediately: boolean?,
	equals: ((a: T, b: T?) -> boolean)?,
	onError: (error: unknown) -> ()?,
	scheduler: (fn: () -> ()) -> ()?,
	once: boolean?,
}

local function untracked<T>(callback: () -> T): T
	pauseTracking()
	local success, result = pcall(callback)
	resumeTracking()
	if not success then
		error(result)
	end
	return result
end

local function reaction<T>(
	dataFn: () -> T,
	effectFn: (newValue: T, oldValue: T?) -> (),
	options: ReactionOptions<T>?
): () -> ()
	local options: ReactionOptions<T> = options or {}
	local scheduler: (() -> ()) -> () = options.scheduler or function(fn)
		return fn()
	end
	local equals: (T, T?) -> boolean = options.equals or function(a, b)
		return a == b
	end
	local onError = options.onError
	local once = options.once or false
	local fireImmediately = options.fireImmediately or false

	local prevValue: T?
	local version = 0

	local tracked = computed(function()
		local success, result = pcall(dataFn)
		if not success then
			untracked(function()
				if onError then
					onError(result)
				end
				return nil
			end)
			return prevValue
		end
		return result
	end)

	local dispose
	dispose = effect(function()
		local current = tracked()
		if not fireImmediately and version == 0 then
			prevValue = current
		end
		version += 1
		if equals(current :: T, prevValue) then
			return
		end
		local oldValue = prevValue
		prevValue = current
		untracked(function()
			scheduler(function()
				local success = pcall(effectFn, current :: T, oldValue)
				if not success and onError then
					onError(error)
				end
				if once then
					if (fireImmediately and version > 1) or (not fireImmediately and version > 0) then
						dispose()
					end
				end
			end)
			return nil
		end)
	end)

	return dispose
end

test("#48", function()
	local source = signal(0)
	local disposeInner: () -> ()

	reaction(function()
		return source()
	end, function(val)
		if val == 1 then
			disposeInner = reaction(function()
				return source()
			end, function() end)
		elseif val == 2 then
			disposeInner()
		end
	end)

	source(1)
	source(2)
	source(3)
end)

return {}
