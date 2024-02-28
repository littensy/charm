local RunService = game:GetService("RunService")

local function setInterval(callback: () -> (), seconds: number): () -> ()
	if seconds < 0 then
		return function() end
	end

	local clock = 0

	local connection = RunService.Heartbeat:Connect(function(delta)
		clock += delta
		if clock >= seconds then
			clock = 0
			callback()
		end
	end)

	return function()
		connection:Disconnect()
	end
end

return setInterval
