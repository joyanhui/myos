-- Helix-like keybindings for Neovim.
-- Port of the keybind logic from VyTrg/helix.nvim (a fork of kak.nvim), inlined into one file.
-- No plugins are required.

vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.loaded_matchit = 1

local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.scrolloff = 5
opt.wrap = false
opt.mouse = "a"
opt.termguicolors = true
opt.signcolumn = "yes:1"
opt.updatetime = 300
opt.timeoutlen = 300
opt.undofile = true
opt.undodir = vim.fn.stdpath("state") .. "/undo"
opt.completeopt = "menu,menuone,popup,noinsert,noselect"
opt.clipboard = vim.fn.has("clipboard") == 1 and "unnamedplus" or ""
opt.expandtab = true
opt.shiftwidth = 4
opt.tabstop = 4
opt.softtabstop = 0
opt.smartindent = true
opt.ignorecase = true
opt.smartcase = true
opt.splitright = true
opt.splitbelow = true
opt.guicursor = "n:block,i-ci:ver25,v:hor25"

vim.fn.mkdir(opt.undodir:get()[1], "p")

local function keycode(str)
	return vim.api.nvim_replace_termcodes(str, true, true, true)
end

local function wrap_key(key)
	return "<A-" .. key .. ">"
end

local keymap = {
	defaults = {
		countable = true,
		opts = {},
		getcharstr = false,
		presets = { "reselect" },
	},
	_inner_defaults = {
		countable = true,
		pre_count = false,
		mode = "n",
		opts = {},
		post_first_str_extra_str = "",
		pre_key_str = "",
		getcharstr = false,
	},
}

local function set(keys, opts)
	opts = opts or {}
	local opts_new = vim.tbl_extend("force", keymap.defaults, opts)
	for _, preset in ipairs(opts_new.presets) do
		local keymap_preset = vim.tbl_extend("force", keymap.presets.Defaults, keymap.presets[preset])
		for _, mode in ipairs(keymap_preset.Modes) do
			local preset_opts = vim.tbl_extend("force", keymap_preset, keymap_preset[mode])
			local items = keys
			if type(items) ~= "table" then
				items = { items }
			end
			for _, key in ipairs(items) do
				preset_opts = vim.tbl_extend("force", preset_opts, preset_opts.Extra_opts_func(key))
				if opts.getcharstr ~= nil then
					preset_opts.getcharstr = opts_new.getcharstr
				end
				if opts.countable ~= nil then
					preset_opts.countable = opts_new.countable
				end

				local lhs_key
				local rhs_key
				if type(key) == "table" then
					lhs_key = preset_opts.Lhs_key_func_force and preset_opts.Lhs_key_func(key[1]) or key[1]
					rhs_key = preset_opts.Rhs_key_func_force and preset_opts.Rhs_key_func(key[2]) or key[2]
				else
					lhs_key = preset_opts.Lhs_key_func(key)
					rhs_key = preset_opts.Rhs_key_func(key)
				end
				keymap._set(lhs_key, rhs_key, preset_opts)
			end
		end
	end
end

function keymap._set(key, resulting_key, opts)
	opts = vim.tbl_extend("force", keymap._inner_defaults, opts or {})
	opts.second_resulting_key = opts.second_resulting_key or resulting_key

	local rhs = function()
		local char = ""
		if opts.getcharstr then
			char = vim.fn.getcharstr() or ""
		end
		local resulting_resulting_key = resulting_key .. char

		local count = ""
		if opts.countable and vim.v.count >= 1 then
			count = "" .. vim.v.count
		end
		local pre_count = count
		if opts.pre_count then
			local n = vim.v.count
			pre_count = "" .. n - 1 .. resulting_resulting_key
			if n <= 1 then
				pre_count = ""
			else
				resulting_resulting_key = opts.second_resulting_key .. char
			end
		end

		vim.cmd("norm! " .. opts.post_first_str_extra_str .. pre_count .. opts.pre_key_str .. resulting_resulting_key)
	end

	vim.keymap.set(opts.mode, key, rhs, opts.opts)
end

keymap.presets = {
	Defaults = {
		Modes = { "Normal_mode", "Visual_mode" },
		Lhs_key_func = function(key)
			return key
		end,
		Rhs_key_func = function(key)
			return key
		end,
		Lhs_key_func_force = false,
		Rhs_key_func_force = false,
		Normal_mode = { mode = "n" },
		Visual_mode = { mode = "x" },
		Extra_opts_func = function()
			return {}
		end,
	},
	reselect = {
		pre_count = true,
		pre_key_str = "v",
		Visual_mode = {
			mode = "x",
			post_first_str_extra_str = keycode("<Esc>"),
		},
	},
	deselect = {
		Visual_mode = {
			mode = "x",
			post_first_str_extra_str = keycode("<Esc>"),
		},
	},
	extend = {
		Lhs_key_func = string.upper,
		Normal_mode = {
			mode = "n",
			post_first_str_extra_str = "v",
		},
	},
	put = {
		Modes = { "Visual_mode" },
		Visual_mode = {
			mode = "x",
			Extra_opts_func = function(key)
				local base = keycode("<Esc>") .. "`"
				if string.match(key, "%u") then
					return { post_first_str_extra_str = base .. "<", second_resulting_key = "p" }
				end
				return { post_first_str_extra_str = base .. ">" }
			end,
		},
	},
	around_inside = {
		Lhs_key_func = wrap_key,
		getcharstr = true,
		countable = false,
		Normal_mode = {
			mode = "n",
			Rhs_key_func = function(key)
				return "v" .. key
			end,
		},
		Visual_mode = {
			mode = "x",
			Rhs_key_func = function(key)
				return keycode("<Esc>") .. "v" .. key
			end,
		},
	},
	nonormal = {
		Modes = { "Visual_mode" },
	},
	none = {},
}

local function extend_preset(parent, name, overrides)
	keymap.presets[name] = vim.tbl_extend("force", keymap.presets[parent], overrides)
end

local alternate_override = {
	Lhs_key_func = wrap_key,
	Rhs_key_func = string.upper,
}
extend_preset("reselect", "alternate", alternate_override)
extend_preset("extend", "alternate_extend", alternate_override)

extend_preset("extend", "goto_extend", {
	Lhs_key_func_force = true,
	Lhs_key_func = function(key)
		return (string.gsub(key, "^%l", string.upper))
	end,
})

local movement = { "h", "j", "k", "l" }
local word = { "w", "e", "b" }

set(movement, { presets = { "deselect", "extend" } })
set(word, { presets = { "reselect", "extend", "alternate" } })
set({ "f", "t" }, { presets = { "reselect", "extend", "alternate_extend" }, getcharstr = true })

set({ { "<A-h>", "0" }, { "<A-l>", "$" } }, { presets = { "reselect" }, countable = false })
set({ { "gh", "0" }, { "gl", "$" } }, { presets = { "deselect", "goto_extend" }, countable = false })
set({
	{ "gg", "gg0" },
	{ "ge", "G$" },
	{ "gj", "G" },
	{ "gk", "gg" },
	{ "gt", "H" },
	{ "gc", "M" },
	{ "gb", "L" },
}, { presets = { "deselect", "goto_extend" }, countable = false })
vim.keymap.set({ "n", "x" }, "G", "", { desc = "Goto extend" })

set({ { "<A-j>", "J" } }, { presets = { "none" }, opts = { desc = "Join lines" } })

set({ "p", "P" }, { presets = { "put" } })
set({ { "R", "p" } }, { presets = { "extend" } })

for _, key in ipairs({ { "o", ">" }, { "O", "<" } }) do
	vim.keymap.set("x", key[1], "<Esc>`" .. key[2] .. key[1], { desc = "Open newline" })
	vim.keymap.set("x", wrap_key(key[1]), "<Esc>`" .. key[2] .. key[1] .. "<Esc>gv", { desc = "Open newline" })
end
set({ { "<A-;>", "o" } }, { presets = { "nonormal" } })

set({ "i", "a" }, { presets = { "around_inside" } })

vim.keymap.set({ "n", "x" }, "%", "ggVG", { desc = "Select all (Helix style)", remap = false })

vim.keymap.set("n", "<C-c>", "gcc", { remap = true, desc = "Toggle comment line" })
vim.keymap.set("x", "<C-c>", "gc", { remap = true, desc = "Toggle comment selection" })

for _, key in ipairs({ "d", "c", "y" }) do
	vim.keymap.set("n", key, "v" .. key, { desc = "Helix style " .. key })
end
vim.keymap.set({ "n", "x" }, "x", "V", { desc = "Select line" })
vim.keymap.set("n", "U", "<C-r>", { desc = "Redo" })

vim.api.nvim_create_autocmd("TextYankPost", {
	callback = function()
		vim.hl.on_yank({ timeout = 150 })
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	callback = function()
		pcall(vim.treesitter.start)
	end,
})
