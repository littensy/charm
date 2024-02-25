--!nocheck

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local DevPackages = ReplicatedStorage.DevPackages

local TestEZ = require(DevPackages.TestEZ)

TestEZ.TestBootstrap:run({ Packages.charm.__tests__ }, TestEZ.Reporters.TextReporter)
