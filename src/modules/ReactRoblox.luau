local Package = script.Parent.Parent
local Packages = if Package.Parent:FindFirstChild("ReactRoblox")
	then Package.Parent
	else Package.Parent:FindFirstChild("ReactLua")

type ReactRoblox = typeof(require(Package.Parent.ReactRoblox))

return (if Packages then require(Packages.ReactRoblox) else nil) :: ReactRoblox
