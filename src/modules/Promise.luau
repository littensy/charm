local Package = script.Parent.Parent

if _G[script] then
	return _G[script].Promise
end

assert(Package.Parent:FindFirstChild("Promise"), `Could not find Promise in {Package.Parent:GetFullName()}`)

return require(Package.Parent.Promise)
