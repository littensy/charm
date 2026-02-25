if not script then
	return require("../charm/src")
end

local Charm = require(script.Parent.Parent.charm.src)

export type Atom<T = any> = Charm.Atom<T>

return Charm
