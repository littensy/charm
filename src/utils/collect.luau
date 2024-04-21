local function collect()
	for _ = 1, 1e4 do
		local _ = table.create(1e3)
	end
	task.wait()
end

return collect
