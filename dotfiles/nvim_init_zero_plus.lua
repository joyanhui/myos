-- nvim_init_zero_plus.lua
-- Simple single-file IDE config for Neovim >= 0.12, no third-party plugins.
--
-- keys:
--   gd / gD / gr / K / <leader>ca / <leader>cr / <leader>cf   lsp: definition, declaration, references, hover, action, rename, format
--   [d / ]d / <leader>dd / <leader>dq                          diagnostics
--   <leader>sg / <leader>sr / <leader>sF                       grep project, replace project, replace buffer

local api = vim.api
local fn = vim.fn

vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- options
vim.o.termguicolors = true
vim.o.number = true
vim.o.relativenumber = true
vim.o.signcolumn = "yes:1"
vim.o.cursorline = true
vim.o.scrolloff = 4
vim.o.splitright = true
vim.o.splitbelow = true
vim.o.timeoutlen = 400
vim.o.updatetime = 250
vim.o.confirm = true
vim.o.hidden = true
vim.o.swapfile = false
vim.o.undofile = true
vim.o.undodir = fn.stdpath("state") .. "/undo"
fn.mkdir(vim.o.undodir, "p")
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.inccommand = "nosplit"
vim.o.expandtab = true
vim.o.shiftwidth = 4
vim.o.tabstop = 4
vim.o.list = true
vim.o.listchars = "tab:» ,trail:·,nbsp:␣"
vim.o.completeopt = "menu,menuone,popup,fuzzy,noselect"
vim.o.pumheight = 12
vim.o.wildmode = "longest:full,full"
vim.o.wildoptions = "pum,fuzzy"
vim.o.grepprg = "rg --vimgrep --no-heading --smart-case --no-messages"
vim.o.grepformat = "%f:%l:%c:%m"
if fn.has("clipboard") == 1 or fn.executable("wl-copy") == 1 then
  vim.o.clipboard = "unnamedplus"
end

local map = function(mode, lhs, rhs, opts)
  opts = opts or {}
  vim.keymap.set(mode, lhs, rhs, opts)
end

local function notify(msg, level)
  vim.notify(tostring(msg), level or vim.log.levels.INFO, { title = "nzp" })
end

local group = api.nvim_create_augroup("NzpCore", { clear = true })

api.nvim_create_autocmd("TextYankPost", {
  group = group,
  callback = function()
    vim.highlight.on_yank({ timeout = 150 })
  end,
})

api.nvim_create_autocmd("BufReadPost", {
  group = group,
  callback = function(ev)
    local mark = api.nvim_buf_get_mark(ev.buf, '"')
    if mark[1] > 0 and mark[1] <= api.nvim_buf_line_count(ev.buf) then
      pcall(api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = { "markdown", "text", "gitcommit" },
  callback = function()
    vim.wo.wrap = true
    vim.wo.linebreak = true
    vim.wo.list = false
  end,
})

-- window and quickfix keys
map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "clear search highlight" })
map("n", "<C-h>", "<C-w>h", { silent = true, desc = "left window" })
map("n", "<C-j>", "<C-w>j", { silent = true, desc = "down window" })
map("n", "<C-k>", "<C-w>k", { silent = true, desc = "up window" })
map("n", "<C-l>", "<C-w>l", { silent = true, desc = "right window" })
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "previous buffer" })
map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "next buffer" })
map("n", "<leader>xx", "<cmd>copen<cr>", { desc = "open quickfix" })
map("n", "<leader>xX", "<cmd>cclose<cr>", { desc = "close quickfix" })
map("n", "]q", "<cmd>cnext<cr>", { desc = "next quickfix item" })
map("n", "[q", "<cmd>cprevious<cr>", { desc = "previous quickfix item" })

vim.g.netrw_banner = 0
map("n", "<leader>e", "<cmd>Lexplore<cr>", { desc = "file explorer" })

-- treesitter
api.nvim_create_autocmd("FileType", {
  group = group,
  callback = function(ev)
    if vim.bo[ev.buf].buftype == "" then
      pcall(vim.treesitter.start, ev.buf)
    end
  end,
})

-- lsp
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
  if fn.executable(server.cmd[1]) == 1 then
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

api.nvim_create_autocmd("LspAttach", {
  group = group,
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
    m("n", "K", vim.lsp.buf.hover, "hover")
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
map("n", "<leader>tf", function()
  format_on_save = not format_on_save
  notify("format on save: " .. tostring(format_on_save))
end, { desc = "toggle format on save" })

api.nvim_create_autocmd("BufWritePre", {
  group = group,
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

map("n", "[d", function()
  diag_jump(-1)
end, { desc = "previous diagnostic" })
map("n", "]d", function()
  diag_jump(1)
end, { desc = "next diagnostic" })
map("n", "<leader>dd", vim.diagnostic.open_float, { desc = "line diagnostics" })
map("n", "<leader>dq", function()
  vim.diagnostic.setqflist()
  vim.cmd("copen")
end, { desc = "diagnostics to quickfix" })

-- search and replace
local function list_files()
  local res = vim.system({ "rg", "--files", "--hidden", "--glob", "!.git" }, { text = true, timeout = 15000 }):wait()
  return vim.split((res and res.stdout) or "", "\n", { trimempty = true })
end

map("n", "<leader>sf", function()
  local files = list_files()
  vim.ui.input({ prompt = "File: " }, function(value)
    if not value or value == "" then
      return
    end
    local matches = fn.matchfuzzy(files, value)
    if #matches == 0 then
      notify("no file: " .. value, vim.log.levels.WARN)
      return
    end
    if #matches == 1 then
      vim.cmd("edit " .. fn.fnameescape(matches[1]))
      return
    end
    local items = {}
    for _, file in ipairs(matches) do
      items[#items + 1] = { filename = file, lnum = 1, col = 1, text = file }
    end
    fn.setqflist({}, " ", { title = "Files: " .. value, items = items })
    vim.cmd("copen")
  end)
end, { desc = "find files" })

local function rg_entries(pattern, opts)
  opts = opts or {}
  local base = opts.cwd or (vim.fs.root(0, ".git") or fn.getcwd())
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

map("n", "<leader>sg", function()
  vim.ui.input({ prompt = "Grep: ", default = fn.expand("<cword>") }, function(value)
    if not value or value == "" then
      return
    end
    local entries = rg_entries(value)
    if #entries == 0 then
      notify("no match: " .. value, vim.log.levels.WARN)
      return
    end
    fn.setqflist({}, " ", { title = "Grep: " .. value, items = entries })
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
    local bufnr = fn.bufadd(file)
    fn.bufload(bufnr)
    local edited = false
    api.nvim_buf_call(bufnr, function()
      for _, e in ipairs(list) do
        local line = api.nvim_buf_get_lines(bufnr, e.lnum - 1, e.lnum, false)[1]
        if line and line:sub(e.col, e.col + #needle - 1) == needle then
          if edited then
            pcall(vim.cmd, "undojoin")
          end
          api.nvim_buf_set_text(bufnr, e.lnum - 1, e.col - 1, e.lnum - 1, e.col - 1 + #needle, { replacement })
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
  vim.ui.input({ prompt = "Find (literal): ", default = fn.expand("<cword>") }, function(needle)
    if not needle or needle == "" or needle:find("\n", 1, true) then
      return
    end
    vim.ui.input({ prompt = ("Replace %q with: "):format(needle), default = "" }, function(replacement)
      if replacement == nil then
        return
      end
      local opts = { fixed = true }
      if scope == "buffer" then
        local path = api.nvim_buf_get_name(0)
        if path == "" then
          notify("buffer has no file", vim.log.levels.WARN)
          return
        end
        local base = vim.fs.root(0, ".git") or fn.getcwd()
        opts.cwd = base
        opts.paths = { path }
      end
      local entries = rg_entries(needle, opts)
      if #entries == 0 then
        notify("no match: " .. needle, vim.log.levels.WARN)
        return
      end
      fn.setqflist({}, " ", { title = "Replace: " .. needle, items = entries })
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

map("n", "<leader>sr", function()
  replace("project")
end, { desc = "replace in project" })
map("n", "<leader>sF", function()
  replace("buffer")
end, { desc = "replace in buffer" })
