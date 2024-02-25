local reference = require(script.Parent.utils.reference)

type AtomInternal<T> = {
	--- @deprecated
	setForced: (self: AtomInternal<T>, state: T | ((T) -> T)) -> (),
	--- @deprecated
	listeners: { [(T) -> ()]: true },
	--- @deprecated
	debugTraceback: string,
	--- @deprecated
	debugLabel: string,
	--- @deprecated
	owners: { [any]: true },
}

export type Atom<T> = (() -> T) & ((state: T | ((T) -> T)) -> ()) & {
	get: ((self: Atom<T>) -> T) & (<Result>(self: Atom<T>, selector: (T) -> Result) -> Result),
	set: (self: Atom<T>, state: T | ((T) -> T)) -> (),
	memo: (self: Atom<T>, equalityFn: (previous: T, current: T) -> boolean) -> Atom<T>,
	writable: (self: Atom<T>, setter: ((update: T, previous: T) -> T?) & (update: T, previous: T) -> ()) -> Atom<T>,
	readonly: (self: Atom<T>) -> ReadonlyAtom<T>,
	named: (self: Atom<T>, label: string) -> Atom<T>,
	unmount: (self: Atom<T>) -> (),
} & AtomInternal<T>

export type ReadonlyAtom<T> = (() -> T) & {
	get: ((self: ReadonlyAtom<T>) -> T) & (<Result>(self: ReadonlyAtom<T>, selector: (T) -> Result) -> Result),
	memo: (self: ReadonlyAtom<T>, equalityFn: (previous: T, current: T) -> boolean) -> ReadonlyAtom<T>,
	writable: ((self: Atom<T>) -> Atom<T>) & (
		(self: Atom<T>, setter: ((update: T, previous: T) -> T?) & (update: T, previous: T) -> ()) -> Atom<T>
	),
	readonly: (self: ReadonlyAtom<T>) -> ReadonlyAtom<T>,
	named: (self: ReadonlyAtom<T>, label: string) -> ReadonlyAtom<T>,
	unmount: (self: ReadonlyAtom<T>) -> (),
} & AtomInternal<T>

local atomCount = 0

local function atom<State>(state: State): Atom<State>
	atomCount += 1

	local listeners: { [(State) -> ()]: true } = {}
	local label = `atom{atomCount}`
	local traceback = debug.traceback(nil, 2)
	local owners: { [any]: true } = {}

	local atom = {
		listeners = listeners,
		debugTraceback = traceback,
		debugLabel = label,
		owners = owners,
	} :: Atom<State>

	local equals: ((State, State) -> boolean)?
	local setter: ((State, State) -> State?)?

	function atom:get<Result>(selector: ((State) -> Result)?): any
		return if selector then selector(state) else state
	end

	function atom:set(update: State | ((State) -> State))
		local nextState = if type(update) == "function" then update(state) else update

		if setter then
			local result = setter(nextState, state)

			if result == nil then
				return
			else
				nextState = result
			end
		end

		if not (if equals then equals(state, nextState) else state == nextState) then
			state = nextState

			for listener in table.clone(listeners) do
				listener(state)
			end
		end
	end

	function atom:setForced(update: State | ((State) -> State))
		local nextState = if type(update) == "function" then update(state) else update

		if not (if equals then equals(state, nextState) else state == nextState) then
			state = nextState

			for listener in table.clone(listeners) do
				listener(state)
			end
		end
	end

	function atom:memo(equalityFn: (State, State) -> boolean): Atom<State>
		equals = equalityFn
		return self
	end

	function atom:writable(setterFn: ((State, State) -> State?)?): Atom<State>
		setter = setterFn
		return self
	end

	function atom:readonly(): ReadonlyAtom<State>
		function setter(_, _)
			error(`Attempt to set read-only atom '{label}' created at: {traceback}`, 3)
		end
		return self
	end

	function atom:named(name: string): Atom<State>
		label = name
		return self
	end

	function atom:unmount()
		table.clear(listeners)
		table.clear(owners)
		reference.release(self)
	end

	setmetatable(atom :: AtomInternal<State>, {
		__type = "Atom",
		__call = function(self, ...)
			if select("#", ...) > 0 then
				return self:set((...))
			else
				return self:get()
			end
		end,
	})

	return atom
end

return atom
