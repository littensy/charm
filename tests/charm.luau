return if game
	then require(game:GetService("ReplicatedStorage").Packages.Charm)
	else require("../packages/charm/src/lib")
