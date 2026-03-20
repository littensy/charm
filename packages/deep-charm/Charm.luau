if not script then
	return require("../charm/src")
end

return require(script.Parent.Parent.charm.src)
