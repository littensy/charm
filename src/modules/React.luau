local Package = script.Parent.Parent
local Packages = if Package.Parent:FindFirstChild("React")
	then Package.Parent
	else Package.Parent:FindFirstChild("ReactLua")

type React = typeof(require(Package.Parent.React))

local React: React

return function()
	if not React then
		React = Packages and require(Packages.React) :: React
	end
	return React
end
