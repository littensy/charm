local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.DevPackages.charm)
local atom = Charm.atom
local Vide = require(ReplicatedStorage.DevPackages.Vide)
local root = Vide.root
local VideCharm = require(ReplicatedStorage.DevPackages["vide-charm"])
local useAtom = VideCharm.useAtom

return function()
	it("tracks atom state", function()
		local state = atom(0)
		local source
		local cleanup = root(function()
			source = useAtom(state)
		end)
		expect(source()).to.equal(0)
		state(1)
		expect(source()).to.equal(1)
		cleanup()
	end)

	it("accepts a selector", function()
		local state = atom(0)
		local source
		local cleanup = root(function()
			source = useAtom(function()
				return 2 * state()
			end)
		end)
		expect(source()).to.equal(0)
		state(1)
		expect(source()).to.equal(2)
		cleanup()
	end)
end
