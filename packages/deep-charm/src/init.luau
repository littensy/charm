local Charm = require("./Charm")

local computed = Charm.computed
local trigger = Charm.trigger
local getActiveSub = Charm.getActiveSub

export type ReactiveProxy<T = any> = typeof(setmetatable(
	{} :: {
		__track: () -> (),
		__target: T,
		__signals: { [unknown]: () -> unknown },
	},
	{} :: { __index: T }
))

local ReactiveProxy = {
	proxyMap = setmetatable({} :: { [any]: ReactiveProxy }, { __mode = "v" }),
}

--[[
	Determines if the provided value is a reactive proxy created by `reactive()`.

	@see https://github.com/littensy/charm?tab=readme-ov-file#reactiveinitialvalue
]]
local function isReactive(value: any): boolean
	return type(value) == "table" and getmetatable(value) == ReactiveProxy
end

--[[
	Unwraps a reactive proxy to get the original table. If the provided value
	is not a proxy, it is returned as-is.

	@param value A reactive proxy or a non-proxy value
	@return The source table if `value` is a reactive proxy
	@see https://github.com/littensy/charm?tab=readme-ov-file#reactiveinitialvalue
]]
local function toRaw<T>(value: T): T
	if isReactive(value) then
		value = value :: ReactiveProxy<T>
		value.__track()
		return toRaw(value.__target)
	end
	return value
end

--[[
	Creates a deep reactive value that tracks properties when they're accessed.
	Returns a proxy object that subscribes to changes on any nested property
	you read, and a function for mutating the original table.

	@example
	```luau
	local users, updateUsers = reactive({
		{ name = "John", surname = "Doe" },
	})

	effect(function()
		print(`{users[1].name} {users[1].surname}`)
	end)

	updateUsers(function(state)
		state[1].name = "Jane"
		state[1].surname = "Smith"
	end)
	```

	@param initialValue Source table to make deeply reactive
	@return A proxy table that tracks reads to nested properties
	@return A function for batching mutations to the source table
	@see https://github.com/littensy/charm?tab=readme-ov-file#reactiveinitialvalue
]]
local function reactive<T>(initialValue: T & {}, trackParent: (() -> ())?): (T, (update: ((T) -> ())?) -> ())
	initialValue = toRaw(initialValue)

	local proxy = ReactiveProxy.proxyMap[initialValue]

	if not proxy then
		local track = computed(function(version: number?)
			-- Reference the proxy to avoid GCing while an effect is actively
			-- tracking this reactive object.
			local _ref = proxy
			-- Allow updates from the parent to propagate down when the
			-- target is mutated directly through the setter.
			if trackParent then
				trackParent()
			end
			return (version or 0) + 1
		end)

		proxy = setmetatable({
			__target = initialValue,
			__signals = setmetatable({}, { __mode = "v" }) :: any,
			__track = track,
		}, ReactiveProxy)

		ReactiveProxy.proxyMap[initialValue] = proxy
	end

	local function setValue(update: ((T) -> ())?)
		if update then
			update(proxy.__target)
		end
		trigger(proxy.__track)
	end

	return proxy :: any, setValue
end

--[[
	Wraps a value in `reactive()` if it is a table; otherwise, returns the
	value as-is.

	@param value Source value to make deeply reactive
	@param trackParent Optional tracking function to propagate deep updates
	@return A reactive proxy if the value is a table
]]
local function toReactive<T>(value: T, trackParent: (() -> ())?): T
	return if type(value) == "table" then reactive(value, trackParent) else value
end

function ReactiveProxy.__index(self: ReactiveProxy, key: any): any
	local track = self.__track
	local signals = self.__signals
	local target = self.__target

	if getActiveSub() then
		if not signals[key] then
			signals[key] = computed(function()
				track()
				return target[key]
			end)
		end
		signals[key]()
	end

	return toReactive(target[key], track)
end

function ReactiveProxy.__newindex(self: ReactiveProxy, key: any, value: any)
	value = toRaw(value)
	if self.__target[key] ~= value then
		self.__target[key] = value
		trigger(self.__track)
	end
end

function ReactiveProxy.__iter(self: ReactiveProxy)
	self.__track()
	local function nextReactive(target: any, prevKey: any)
		local nextKey, nextValue = next(target, prevKey)
		return nextKey, toReactive(nextValue, self.__track)
	end
	return nextReactive, self.__target
end

function ReactiveProxy.__len(self: ReactiveProxy)
	self.__track()
	return #self.__target
end

return {
	reactive = reactive,
	isReactive = isReactive,
	toRaw = toRaw,
}
