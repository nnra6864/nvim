local M = {}
M.theme = function()
	return {
		inactive = {
			a = { fg = "#A3C5CC", bg = "#041C26", gui = "bold" },
			b = { fg = "#A3C5CC", bg = "#082E3F" },
			c = { fg = "#A3C5CC", bg = nil },
		},
		visual = {
			a = { fg = "#A3C5CC", bg = "#267180", gui = "bold" },
			b = { fg = "#A3C5CC", bg = "#082E3F" },
			c = { fg = "#A3C5CC", bg = nil },
		},
		replace = {
			a = { fg = "#A3C5CC", bg = "#80333C", gui = "bold" },
			b = { fg = "#A3C5CC", bg = "#082E3F" },
			c = { fg = "#A3C5CC", bg = nil },
		},
		normal = {
			a = { fg = "#A3C5CC", bg = "#041C26", gui = "bold" },
			b = { fg = "#A3C5CC", bg = "#082E3F" },
			c = { fg = "#A3C5CC", bg = nil },
		},
		insert = {
			a = { fg = "#041C26", bg = "#338051", gui = "bold" },
			b = { fg = "#A3C5CC", bg = "#082E3F" },
			c = { fg = "#A3C5CC", bg = nil },
		},
		command = {
			a = { fg = "#041C26", bg = "#668033", gui = "bold" },
			b = { fg = "#A3C5CC", bg = "#082E3F" },
			c = { fg = "#A3C5CC", bg = nil },
		},
	}
end
return M
