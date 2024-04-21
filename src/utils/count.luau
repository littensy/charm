local function count(object: any): number
	local count = 0
	for _ in next, object do
		count += 1
	end
	return count
end

return count
