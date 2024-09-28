local Package = script.Parent.Parent
local Index = script:FindFirstAncestor("_Index")
local Packages = if Package.Parent:FindFirstChild("React")
	then Package.Parent
	elseif Index then Index.Parent
	else Package.Parent.Parent:FindFirstChild("ReactLua")

type React = typeof(require(Package.Parent.React))

local React: React

return function()
	if not React then
		React = Packages and require(Packages.React) :: React
	end
	return React
end
