local RunService = game:GetService("RunService")

--[=[
	Schedules a function to be called at a fixed interval of `seconds`.
	
	@param callback The function to call.
	@param seconds The interval in seconds.
	@return A function that cancels the interval.
]=]
local function interval(callback: () -> (), seconds: number): () -> ()
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

return interval
