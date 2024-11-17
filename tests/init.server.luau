--!nocheck

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestEZ = require(ReplicatedStorage.DevPackages.TestEZ)

-- Start Charm in debug mode
_G.__DEV__ = true
require(ReplicatedStorage.DevPackages.Charm)
_G.__DEV__ = false

TestEZ.TestBootstrap:run({ script.Parent }, TestEZ.Reporters.TextReporter)
