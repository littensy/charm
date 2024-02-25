local refs = {}

--- Prevents the garbage collector from collecting a value
local function hold(value: unknown)
	refs[value] = true
end

--- Allows the garbage collector to collect a value
local function release(value: unknown)
	refs[value] = nil
end

--- Clears all held references
local function clear()
	table.clear(refs)
end

--- Returns a function that retrieves the value through a weak reference
local function weak<T>(value: T): () -> T?
	local set = setmetatable({ value }, { __mode = "v" })
	return function()
		return set[1]
	end
end

return {
	hold = hold,
	release = release,
	clear = clear,
	weak = weak,
}
