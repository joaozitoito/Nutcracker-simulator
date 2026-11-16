-- 1234 -> "1.2k"
local suffixes = { "", "k", "M", "B", "T" }

return function(n: number): string
	local i = 1
	while n >= 1000 and i < #suffixes do
		n /= 1000
		i += 1
	end
	if i == 1 then
		return tostring(math.floor(n))
	end
	return (string.format("%.1f", math.floor(n * 10) / 10):gsub("%.0$", "")) .. suffixes[i]
end
