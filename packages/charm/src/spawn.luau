local freeThread: thread?

local function run<T...>(thread: thread, fn: (T...) -> (), ...: T...): boolean
	fn(...)
	if freeThread then
		return true
	else
		freeThread = thread
		return false
	end
end

local function runner()
	local quit = false
	repeat
		quit = run(coroutine.yield())
	until quit
end

local function spawn<T...>(callback: (T...) -> (), ...: T...)
	local thread

	if freeThread then
		thread = freeThread
		freeThread = nil
	elseif task then
		thread = task.spawn(runner)
	else
		thread = coroutine.create(runner)
		coroutine.resume(thread)
	end

	coroutine.resume(thread, thread, callback, ...)
end

return spawn
