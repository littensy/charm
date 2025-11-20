if not script then
	return require("../charm/src")
end

local Charm = require(script.Parent.Parent.charm.src)

export type Atom<T = any> = Charm.Atom<T>
export type ReactiveProxy<T = any> = Charm.ReactiveProxy<T>

return Charm
