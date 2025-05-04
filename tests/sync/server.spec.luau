local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Charm = require(ReplicatedStorage.DevPackages.Charm)
local CharmSync = require(ReplicatedStorage.DevPackages.CharmSync)
local patch = require(ReplicatedStorage.DevPackages.CharmSync.patch)
local suite = require(ServerScriptService.Tests.suite)

type SyncPayload = CharmSync.SyncPayload

local atom = Charm.atom
local server = CharmSync.server
local test = suite.test

local target: Player = {} :: any

test("sends state to new players", function()
	local a = atom(1)
	local server = server({ atoms = { a = a }, interval = -1 })
	local player: Player, payload: SyncPayload

	local disconnect = server:connect(function(...)
		player, payload = ...
	end)

	server:hydrate(target)

	assert(player == target)
	assert(payload.type == "init")
	assert(payload.data.a == 1)

	disconnect()
end)

test("sends state patches", function()
	local a = atom({ b = 1, c = 2 } :: { [string]: number? })
	local server = server({ atoms = { a = a }, interval = -1 })
	local player: Player, payload: SyncPayload

	local disconnect = server:connect(function(...)
		player, payload = ...
	end)

	a({ b = 1, c = 5 })
	server:_sendPatch(target)

	assert(player == target)
	assert(payload.type == "patch")
	assert(payload.data.a.b == nil)
	assert(payload.data.a.c == 5)

	a({ b = 1, d = 1 })
	server:_sendPatch(target)

	assert(payload.data.a.b == nil)
	assert(patch.isNone(payload.data.a.c) == true)
	assert(payload.data.a.d == 1)

	disconnect()
end)

test("preserves history", function()
	local a = atom(1)
	local b = atom(1)
	local payloads: { SyncPayload }

	local server = server({
		atoms = { a = a, b = b },
		interval = -1,
		preserveHistory = true,
	})

	local disconnect = server:connect(function(_, ...)
		payloads = { ... }
	end)

	a(2)
	b(2)
	server:_sendPatch(target)

	assert(#payloads == 1)
	assert(payloads[1].type == "patch")
	assert(payloads[1].data.a == 2)
	assert(payloads[1].data.b == 2)

	a(3)
	a(4)
	b(3)
	server:_sendPatch(target)

	assert(#payloads == 2)
	assert(payloads[1].type == "patch")
	assert(payloads[1].data.a == 3)
	assert(payloads[1].data.b == nil)
	assert(payloads[2].type == "patch")
	assert(payloads[2].data.a == 4)
	assert(payloads[2].data.b == 3)

	disconnect()
end)
