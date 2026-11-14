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
opt.clipboard = (vim.fn.has("clipboard") == 1 or vim.fn.executable("wl-copy") == 1) and "unnamedplus" or ""
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
opt.cursorline = true
opt.hidden = true
opt.swapfile = false
opt.confirm = true
opt.inccommand = "nosplit"
opt.pumheight = 12
opt.wildmode = "longest:full,full"
opt.wildoptions = "pum,fuzzy"
opt.grepprg = "rg --vimgrep --no-heading --smart-case --no-messages"
opt.grepformat = "%f:%l:%c:%m"

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
	callback = function(ev)
		if vim.bo[ev.buf].buftype == "" then
			pcall(vim.treesitter.start, ev.buf)
		end
	end,
})

vim.g.netrw_banner = 0

local function notify(msg, level)
	vim.notify(tostring(msg), level or vim.log.levels.INFO, { title = "nvim" })
end

vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "clear search highlight" })

for _, dir in ipairs({ "h", "j", "k", "l" }) do
	vim.keymap.set("n", "<C-" .. dir .. ">", "<C-w>" .. dir, { silent = true, desc = "window " .. dir })
end

vim.keymap.set("n", "]b", "<cmd>bnext<cr>", { desc = "next buffer" })
vim.keymap.set("n", "[b", "<cmd>bprevious<cr>", { desc = "previous buffer" })
vim.keymap.set("n", "<leader>xx", "<cmd>copen<cr>", { desc = "open quickfix" })
vim.keymap.set("n", "<leader>xX", "<cmd>cclose<cr>", { desc = "close quickfix" })
vim.keymap.set("n", "]q", "<cmd>cnext<cr>", { desc = "next quickfix item" })
vim.keymap.set("n", "[q", "<cmd>cprevious<cr>", { desc = "previous quickfix item" })
vim.keymap.set("n", "<leader>e", "<cmd>Lexplore<cr>", { desc = "file explorer" })

local servers = {
	{ name = "lua_ls", cmd = { "lua-language-server" }, filetypes = { "lua" } },
	{ name = "gopls", cmd = { "gopls" }, filetypes = { "go", "gomod", "gowork" } },
	{ name = "rust_analyzer", cmd = { "rust-analyzer" }, filetypes = { "rust" } },
	{ name = "clangd", cmd = { "clangd" }, filetypes = { "c", "cpp", "objc", "objcpp" } },
	{ name = "pyright", cmd = { "pyright-langserver", "--stdio" }, filetypes = { "python" } },
	{ name = "ruff", cmd = { "ruff", "server" }, filetypes = { "python" } },
	{ name = "zls", cmd = { "zls" }, filetypes = { "zig" } },
	{
		name = "ts_ls",
		cmd = { "typescript-language-server", "--stdio" },
		filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
	},
	{ name = "jsonls", cmd = { "vscode-json-language-server", "--stdio" }, filetypes = { "json", "jsonc" } },
	{ name = "yamlls", cmd = { "yaml-language-server", "--stdio" }, filetypes = { "yaml" } },
	{ name = "taplo", cmd = { "taplo", "lsp", "stdio" }, filetypes = { "toml" } },
	{ name = "nixd", cmd = { "nixd" }, filetypes = { "nix" } },
}

vim.lsp.config("*", {
	capabilities = vim.lsp.protocol.make_client_capabilities(),
	root_markers = { ".git", "go.work", "Cargo.toml", "pyproject.toml", "package.json", "flake.nix" },
})

for _, server in ipairs(servers) do
	if vim.fn.executable(server.cmd[1]) == 1 then
		vim.lsp.config(server.name, {
			cmd = server.cmd,
			filetypes = server.filetypes,
			settings = server.name == "lua_ls" and {
				Lua = {
					runtime = { version = "LuaJIT" },
					diagnostics = { globals = { "vim" } },
					workspace = { checkThirdParty = false },
					telemetry = { enable = false },
				},
			} or nil,
		})
		vim.lsp.enable(server.name)
	end
end

vim.diagnostic.config({
	severity_sort = true,
	update_in_insert = false,
	underline = true,
	signs = { text = { "✘", "▲", "●", "◆" } },
	virtual_text = { spacing = 2, prefix = "●", source = false },
	float = { border = "rounded", source = true },
})

vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(ev)
		local client = vim.lsp.get_client_by_id(ev.data.client_id)
		if not client then
			return
		end
		local bufnr = ev.buf
		local function m(mode, lhs, rhs, desc)
			vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
		end
		m("n", "gd", vim.lsp.buf.definition, "definition")
		m("n", "gD", vim.lsp.buf.declaration, "declaration")
		m("n", "gr", vim.lsp.buf.references, "references")
		m("n", "<leader>ch", vim.lsp.buf.hover, "hover")
		m({ "n", "i" }, "<C-k>", vim.lsp.buf.signature_help, "signature help")
		m({ "n", "x" }, "<leader>ca", vim.lsp.buf.code_action, "code action")
		m("n", "<leader>cr", vim.lsp.buf.rename, "rename")
		m("n", "<leader>cf", function()
			vim.lsp.buf.format({ async = true })
		end, "format")
		m("n", "<leader>cd", vim.diagnostic.open_float, "line diagnostics")

		if client:supports_method("textDocument/completion") then
			vim.lsp.completion.enable(true, client.id, bufnr, { autotrigger = true })
		end
		if client:supports_method("textDocument/inlayHint") then
			pcall(vim.lsp.inlay_hint.enable, true, { bufnr = bufnr })
		end
	end,
})

local format_on_save = true
vim.keymap.set("n", "<leader>tf", function()
	format_on_save = not format_on_save
	notify("format on save: " .. tostring(format_on_save))
end, { desc = "toggle format on save" })

vim.api.nvim_create_autocmd("BufWritePre", {
	callback = function(ev)
		if not format_on_save then
			return
		end
		if #vim.lsp.get_clients({ bufnr = ev.buf, method = "textDocument/formatting" }) == 0 then
			return
		end
		pcall(vim.lsp.buf.format, { bufnr = ev.buf, async = false, timeout_ms = 2000 })
	end,
})

local function diag_jump(dir)
	if vim.diagnostic.jump then
		vim.diagnostic.jump({ count = dir, float = true })
	else
		local jump = dir > 0 and vim.diagnostic.goto_next or vim.diagnostic.goto_prev
		jump({ float = true })
	end
end

vim.keymap.set("n", "[d", function()
	diag_jump(-1)
end, { desc = "previous diagnostic" })
vim.keymap.set("n", "]d", function()
	diag_jump(1)
end, { desc = "next diagnostic" })
vim.keymap.set("n", "<leader>dd", vim.diagnostic.open_float, { desc = "line diagnostics" })
vim.keymap.set("n", "<leader>dq", function()
	vim.diagnostic.setqflist()
	vim.cmd("copen")
end, { desc = "diagnostics to quickfix" })

local function list_files()
	local res = vim.system({ "rg", "--files", "--hidden", "--glob", "!.git" }, { text = true, timeout = 15000 }):wait()
	return vim.split((res and res.stdout) or "", "\n", { trimempty = true })
end

vim.keymap.set("n", "<leader>sf", function()
	local files = list_files()
	vim.ui.input({ prompt = "File: " }, function(value)
		if not value or value == "" then
			return
		end
		local matches = vim.fn.matchfuzzy(files, value)
		if #matches == 0 then
			notify("no file: " .. value, vim.log.levels.WARN)
			return
		end
		if #matches == 1 then
			vim.cmd("edit " .. vim.fn.fnameescape(matches[1]))
			return
		end
		local items = {}
		for _, file in ipairs(matches) do
			items[#items + 1] = { filename = file, lnum = 1, col = 1, text = file }
		end
		vim.fn.setqflist({}, " ", { title = "Files: " .. value, items = items })
		vim.cmd("copen")
	end)
end, { desc = "find files" })

local function rg_entries(pattern, opts)
	opts = opts or {}
	local base = opts.cwd or (vim.fs.root(0, ".git") or vim.fn.getcwd())
	local argv = { "rg", "--vimgrep", "--no-heading", "--color=never", "--no-messages", "-e", pattern }
	if opts.fixed then
		argv[#argv + 1] = "--fixed-strings"
	end
	vim.list_extend(argv, opts.paths or {})
	local res = vim.system(argv, { cwd = base, text = true, timeout = 15000 }):wait()
	local entries = {}
	for line in ((res and res.stdout) or ""):gmatch("[^\n]+") do
		local path, lnum, col, text = line:match("^(.-):(%d+):(%d+):(.*)$")
		if path then
			entries[#entries + 1] = {
				filename = path:sub(1, 1) == "/" and path or vim.fs.joinpath(base, path),
				lnum = tonumber(lnum),
				col = tonumber(col),
				text = (text:gsub("^%s+", "")),
			}
		end
	end
	return entries, base
end

vim.keymap.set("n", "<leader>sg", function()
	vim.ui.input({ prompt = "Grep: ", default = vim.fn.expand("<cword>") }, function(value)
		if not value or value == "" then
			return
		end
		local entries = rg_entries(value)
		if #entries == 0 then
			notify("no match: " .. value, vim.log.levels.WARN)
			return
		end
		vim.fn.setqflist({}, " ", { title = "Grep: " .. value, items = entries })
		vim.cmd("copen")
	end)
end, { desc = "grep project" })

local function apply_replace(entries, needle, replacement)
	local by_file = {}
	for _, e in ipairs(entries) do
		by_file[e.filename] = by_file[e.filename] or {}
		table.insert(by_file[e.filename], e)
	end
	local changed, skipped = 0, 0
	for file, list in pairs(by_file) do
		table.sort(list, function(a, b)
			if a.lnum ~= b.lnum then
				return a.lnum > b.lnum
			end
			return a.col > b.col
		end)
		local bufnr = vim.fn.bufadd(file)
		vim.fn.bufload(bufnr)
		local edited = false
		vim.api.nvim_buf_call(bufnr, function()
			for _, e in ipairs(list) do
				local line = vim.api.nvim_buf_get_lines(bufnr, e.lnum - 1, e.lnum, false)[1]
				if line and line:sub(e.col, e.col + #needle - 1) == needle then
					if edited then
						pcall(vim.cmd, "undojoin")
					end
					vim.api.nvim_buf_set_text(
						bufnr,
						e.lnum - 1,
						e.col - 1,
						e.lnum - 1,
						e.col - 1 + #needle,
						{ replacement }
					)
					changed = changed + 1
					edited = true
				else
					skipped = skipped + 1
				end
			end
		end)
	end
	return changed, skipped
end

local function replace(scope)
	vim.ui.input({ prompt = "Find (literal): ", default = vim.fn.expand("<cword>") }, function(needle)
		if not needle or needle == "" or needle:find("\n", 1, true) then
			return
		end
		vim.ui.input({ prompt = ("Replace %q with: "):format(needle), default = "" }, function(replacement)
			if replacement == nil then
				return
			end
			local opts = { fixed = true }
			if scope == "buffer" then
				local path = vim.api.nvim_buf_get_name(0)
				if path == "" then
					notify("buffer has no file", vim.log.levels.WARN)
					return
				end
				opts.cwd = vim.fs.root(0, ".git") or vim.fn.getcwd()
				opts.paths = { path }
			end
			local entries = rg_entries(needle, opts)
			if #entries == 0 then
				notify("no match: " .. needle, vim.log.levels.WARN)
				return
			end
			vim.fn.setqflist({}, " ", { title = "Replace: " .. needle, items = entries })
			vim.cmd("copen")
			vim.ui.input({ prompt = ("%d matches, replace? [y/N]: "):format(#entries) }, function(answer)
				if not answer or not answer:lower():match("^y") then
					return
				end
				local changed, skipped = apply_replace(entries, needle, replacement)
				notify(("replaced %d, skipped %d (modified, not saved)"):format(changed, skipped))
			end)
		end)
	end)
end

vim.keymap.set("n", "<leader>sr", function()
	replace("project")
end, { desc = "replace in project" })
vim.keymap.set("n", "<leader>sF", function()
	replace("buffer")
end, { desc = "replace in buffer" })
