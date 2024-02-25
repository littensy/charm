local Package = script.Parent.Parent
local Packages = if Package.Parent:FindFirstChild("React")
	then Package.Parent
	else Package.Parent:FindFirstChild("ReactLua")

type React = typeof(require(Package.Parent.React))

return (if Packages then require(Packages.React) else nil) :: React
