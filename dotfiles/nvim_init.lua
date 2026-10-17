--  使用 nvim vim.pack 管理插件
--  快捷键 尽可的复刻 lazyvim

local package = package

package.preload["plugins.core"] = function(...)
	return assert(load(
		[[
local pack = require "plugins.pack"

vim.g.mapleader = " "
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.textwidth = 120
vim.opt.swapfile = false
vim.opt.confirm = true
vim.opt.linebreak = true
vim.opt.termguicolors = true
vim.opt.expandtab = true -- expand tabs to spaces
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.completeopt = "menuone,fuzzy,popup,noinsert,noselect"
vim.opt.complete = "o,.,w,b,u"
vim.opt.autocomplete = false
vim.opt.grepprg = "rg --vimgrep --no-messages --smart-case"
vim.opt.smoothscroll = true
vim.opt.wildoptions:append { "fuzzy" }
vim.opt.path:append { "**" }
vim.opt.splitright = true -- more natural split
vim.opt.splitbelow = true -- more natural split

pack.add {
  { src = "https://github.com/nvim-lua/plenary.nvim" },
}

vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.highlight.on_yank()
  end,
})
]],
		"@lua/plugins/core.lua",
		"t",
		_ENV
	))(...)
end

package.preload["plugins.editing"] = function(...)
	return assert(load(
		[=[
local pack = require "plugins.pack"

vim.cmd.packadd "cfilter"
vim.cmd.packadd "nvim.undotree"
vim.cmd.packadd "nvim.difftool"

pack.add {
  { src = "https://github.com/chaoren/vim-wordmotion" },
  { src = "https://github.com/nvim-mini/mini.pairs" },
  { src = "https://github.com/stevearc/conform.nvim" },
  { src = "https://github.com/stevearc/quicker.nvim" },
  {
    src = "https://github.com/nvim-treesitter/nvim-treesitter",
    update_hook = function()
      vim.notify "[nvim-treesitter] TSUpdate"
      vim.cmd "TSUpdate"
    end,
  },
  {
    src = "https://github.com/ravsii/tree-sitter-d2",
    install_hook = function(ev)
      vim.notify "[tree-sitter-d2] make nvim-install"
      vim.system({ "make", "nvim-install" }, { cwd = ev.data.path }):wait()
    end,
    update_hook = function(ev)
      vim.notify "[tree-sitter-d2] make nvim-install"
      vim.system({ "make", "nvim-install" }, { cwd = ev.data.path }):wait()
    end,
  },
  { src = "https://github.com/nvim-treesitter/nvim-treesitter-context" },
  { src = "https://github.com/folke/todo-comments.nvim" },
  { src = "https://github.com/OXY2DEV/markview.nvim" },
  { src = "https://github.com/nacro90/numb.nvim" },
}

require("mini.pairs").setup()

require("quicker").setup {
  keys = {
    {
      ">",
      function()
        require("quicker").expand { before = 2, after = 2, add_to_existing = true }
      end,
      desc = "展开快速修复上下文",
    },
    {
      "<",
      function()
        require("quicker").collapse()
      end,
      desc = "折叠快速修复上下文",
    },
  },
}

require("conform").setup {
  default_format_opts = {
    lsp_format = "fallback",
  },
  formatters_by_ft = {
    go = { "gofmt" },
    javascript = { "prettier" },
    javascriptreact = { "prettier" },
    json = { "prettier" },
    lua = { "stylua" },
    nix = { "alejandra" },
    python = { "black" },
    r = { "air" },
    rust = { "rustfmt" },
    typescript = { "prettier" },
    typescriptreact = { "prettier" },
    zig = { "zigfmt" },
  },
}

vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = { "*.go", "*.nix", "*.rs", "*.ts", "*.tsx", "*.zig" },
  callback = function(args)
    require("conform").format { bufnr = args.buf, lsp_format = "fallback", timeout_ms = 2000 }
  end,
})

vim.keymap.set("n", "glf", function()
  require("conform").format()
end, { silent = true, desc = "格式化缓冲区" })

vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    local ensure_installed = {
      "lua",
      "bash",
      "go",
      "json",
      "markdown",
      "markdown_inline",
      "python",
      "rust",
      "toml",
      "typescript",
      "tsx",
      "yaml",
      "zig",
      "nix",
    }
    local already_installed = require("nvim-treesitter.config").get_installed()
    local parsers_to_install = vim
      .iter(ensure_installed)
      :filter(function(parser)
        return not vim.tbl_contains(already_installed, parser)
      end)
      :totable()

    if #parsers_to_install > 0 then
      require("nvim-treesitter").install(parsers_to_install)
    end
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  callback = function()
    pcall(vim.treesitter.start)
    vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
    vim.wo.foldmethod = "expr"
    vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end,
})
-- scratch buffers
vim.keymap.set("n", "<leader>cc", function()
  require("snacks").scratch()
end, { desc = "切换临时缓冲区" })

vim.keymap.set("n", "<leader>cs", function()
  require("snacks").picker.scratch()
end, { desc = "搜索临时缓冲区" })

-- info comments
require("todo-comments").setup {
  signs = true,
  sign_priority = 8,
  keywords = {
    FIX = {
      icon = " ",
      color = "error",
      alt = { "FIXME", "BUG", "FIXIT", "ISSUE" },
    },
    TODO = { icon = " ", color = "info" },
    HACK = { icon = " ", color = "warning" },
    WARN = { icon = " ", color = "warning", alt = { "WARNING", "XXX" } },
    PERF = { icon = "󰅒 ", alt = { "OPTIM", "PERFORMANCE", "OPTIMIZE" } },
    NOTE = { icon = "󰍨 ", color = "hint", alt = { "INFO" } },
    TEST = { icon = "⏲ ", color = "test", alt = { "TESTING", "PASSED", "FAILED" } },
  },
  gui_style = {
    fg = "NONE",
    bg = "BOLD",
  },
  merge_keywords = true,
  highlight = {
    multiline = true,
    multiline_pattern = "^.",
    multiline_context = 10,
    before = "",
    keyword = "wide",
    after = "fg",
    pattern = [[.*<(KEYWORDS)\s*:]],
    comments_only = true,
    max_line_len = 400,
    exclude = {},
  },
  colors = {
    error = { "DiagnosticError", "ErrorMsg", "#DC2626" },
    warning = { "DiagnosticWarn", "WarningMsg", "#FBBF24" },
    info = { "DiagnosticInfo", "#2563EB" },
    hint = { "DiagnosticHint", "#10B981" },
    default = { "Identifier", "#7C3AED" },
    test = { "Identifier", "#FF00FF" },
  },
  search = {
    command = "rg",
    args = {
      "--color=never",
      "--no-heading",
      "--with-filename",
      "--line-number",
      "--column",
    },
    pattern = [[\b(KEYWORDS):]],
  },
}
-- mappings to navigate/find tags
vim.keymap.set("n", "]t", function()
  require("todo-comments").jump_next()
end, { desc = "下一个待办注释" })

vim.keymap.set("n", "[t", function()
  require("todo-comments").jump_prev()
end, { desc = "上一个待办注释" })

vim.keymap.set("n", "<leader>ftT", function()
  require("snacks").picker.todo_comments()
end, { desc = "查找待办注释" })

vim.keymap.set("n", "<leader>fte", function()
  require("snacks").picker.todo_comments { keywords = { "FIX", "FIXME", "BUX", "FIXIT", "ISSUE" } }
end, { desc = "查找修复类注释 - FIX、FIXME、BUG、ISSUE" })

vim.keymap.set("n", "<leader>fti", function()
  require("snacks").picker.todo_comments { keywords = { "INFO", "NOTE" } }
end, { desc = "查找信息类注释 - INFO、NOTE" })

vim.keymap.set("n", "<leader>ftw", function()
  require("snacks").picker.todo_comments { keywords = { "WARN", "HACK", "WARNING", "XXX" } }
end, { desc = "查找警告类注释 - WARN、HACK" })

vim.keymap.set("n", "<leader>ftt", function()
  require("snacks").picker.todo_comments { keywords = { "TODO" } }
end, { desc = "查找待办类注释 - TODO" })

vim.keymap.set("n", "<leader>ftp", function()
  require("snacks").picker.todo_comments { keywords = { "PERF", "OPTIM", "PERFORMANCE", "OPTOMIZE" } }
end, { desc = "查找性能类注释 - PERF、OPTIM、PERFORMANCE、OPTOMIZE" })

-- numb.nvim
require("numb").setup()
]=],
		"@lua/plugins/editing.lua",
		"t",
		_ENV
	))(...)
end

package.preload["plugins.generators"] = function(...)
	return assert(load(
		[[
local pack = require "plugins.pack"

-- code annotations generator by :Neogen
pack.add {
  { src = "https://github.com/danymat/neogen" },
}
require("neogen").setup()

-- custom one time items generators
local uv = vim.uv or vim.loop
math.randomseed(os.time() + ((uv and uv.hrtime) and math.floor(uv.hrtime() % 1000000) or 0))

local function trim(value)
  return (value:gsub("%s+$", ""))
end

local function rand_hex(length)
  local out = {}
  for _ = 1, length do
    out[#out + 1] = string.format("%x", math.random(0, 15))
  end
  return table.concat(out)
end

local function now_ms()
  local extra = 0
  if uv and uv.hrtime then
    extra = math.floor((uv.hrtime() / 1e6) % 1000)
  end
  return (os.time() * 1000) + extra
end

local function datetime_iso()
  local tz = os.date "%z"
  if #tz == 5 then
    tz = tz:sub(1, 3) .. ":" .. tz:sub(4, 5)
  end
  return os.date "%Y-%m-%dT%H:%M:%S" .. tz
end

local function run_system(argv)
  if vim.fn.executable(argv[1]) == 0 then
    return nil
  end

  local result = vim.fn.system(argv)
  if vim.v.shell_error ~= 0 then
    return nil
  end

  return trim(result):lower()
end

local function uuid_v4_fallback()
  return table.concat {
    rand_hex(8),
    "-",
    rand_hex(4),
    "-4",
    rand_hex(3),
    "-",
    ({ "8", "9", "a", "b" })[math.random(1, 4)],
    rand_hex(3),
    "-",
    rand_hex(12),
  }
end

local function uuid_name()
  local pos = vim.api.nvim_win_get_cursor(0)
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    file = "nvim"
  end
  return string.format("%s:%d:%d:%d", file, pos[1], pos[2], now_ms())
end

local function uuid_v2()
  local v1 = run_system { "uuidgen", "--time" }
  if not v1 then
    return nil
  end

  local _, g2, g3, g4, g5 = v1:match "^(%x+)%-(%x+)%-(%x+)%-(%x+)%-(%x+)$"
  if not g2 then
    return nil
  end

  return string.format("%s-%s-%s-%s-%s", rand_hex(8), g2, "2" .. g3:sub(2), g4:sub(1, 2) .. "00", g5)
end

local CROCKFORD32 = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

local function ulid()
  local ms = now_ms()
  local bytes = {}

  for idx = 6, 1, -1 do
    bytes[idx] = ms % 256
    ms = math.floor(ms / 256)
  end

  for idx = 7, 16 do
    bytes[idx] = math.random(0, 255)
  end

  local chars = {}
  local buffer = 0
  local bits = 0

  for _, byte in ipairs(bytes) do
    buffer = (buffer * 256) + byte
    bits = bits + 8

    while bits >= 5 do
      bits = bits - 5
      local value = math.floor(buffer / (2 ^ bits)) % 32
      chars[#chars + 1] = CROCKFORD32:sub(value + 1, value + 1)
    end

    buffer = buffer % (2 ^ bits)
  end

  if bits > 0 then
    local value = (buffer * (2 ^ (5 - bits))) % 32
    chars[#chars + 1] = CROCKFORD32:sub(value + 1, value + 1)
  end

  return table.concat(chars, "", 1, 26)
end

local generators = {
  {
    id = "uuid1",
    build = function()
      return run_system { "uuidgen", "--time" }
    end,
  },
  { id = "uuid2", build = uuid_v2 },
  {
    id = "uuid3",
    build = function()
      return run_system { "uuidgen", "--md5", "--namespace", "@dns", "--name", uuid_name() }
    end,
  },
  {
    id = "uuid4",
    build = function()
      return run_system { "uuidgen", "--random" } or uuid_v4_fallback()
    end,
  },
  {
    id = "uuid5",
    build = function()
      return run_system { "uuidgen", "--sha1", "--namespace", "@dns", "--name", uuid_name() }
    end,
  },
  {
    id = "uuid6",
    build = function()
      return run_system { "uuidgen", "--time-v6" }
    end,
  },
  {
    id = "uuid7",
    build = function()
      return run_system { "uuidgen", "--time-v7" }
    end,
  },
  { id = "ulid", build = ulid },
  {
    id = "date",
    build = function()
      return os.date "%Y-%m-%d"
    end,
  },
  {
    id = "datetime",
    build = function()
      return os.date "%Y-%m-%d %H:%M:%S"
    end,
  },
  { id = "datetime_iso", build = datetime_iso },
}

local generator_by_id = {}
for _, generator in ipairs(generators) do
  generator_by_id[generator.id] = generator
end

local function insert_text(value)
  if not value or value == "" then
    return
  end

  if not vim.api.nvim_get_mode().mode:match "^i" then
    vim.cmd.startinsert()
  end

  local keys = vim.api.nvim_replace_termcodes(value, true, false, true)
  vim.api.nvim_feedkeys(keys, "i", false)
end

local function insert_generated(id)
  local generator = generator_by_id[id]
  if not generator then
    vim.notify(("Unknown generator: %s"):format(id), vim.log.levels.ERROR)
    return
  end

  local ok, value = pcall(generator.build)
  if not ok or not value or value == "" then
    vim.notify(("Failed to generate: %s"):format(id), vim.log.levels.ERROR)
    return
  end

  insert_text(value)
end

local function generated_completion_items(base)
  local items = {}
  local match_prefix = base and base ~= ""

  for _, generator in ipairs(generators) do
    local ok, value = pcall(generator.build)
    if ok and value and value ~= "" then
      if (not match_prefix) or vim.startswith(value, base) then
        items[#items + 1] = {
          word = value,
          abbr = generator.id,
          menu = "[generated]",
          kind = "g",
        }
      end
    end
  end

  return items
end

function _G.onjin_generated_complete(findstart, base)
  if findstart == 1 then
    local col = vim.fn.col "." - 1
    local line = vim.fn.getline "."
    local start = col
    while start > 0 and line:sub(start, start):match "[%w_]" do
      start = start - 1
    end
    return start
  end

  local items = generated_completion_items(base)
  return items
end

vim.opt.completefunc = "v:lua.onjin_generated_complete"

local function pick_and_insert_generated()
  local items = vim.tbl_map(function(item)
    return item.id
  end, generators)

  vim.ui.select(items, { prompt = "Insert generated value" }, function(choice)
    if choice then
      insert_generated(choice)
    end
  end)
end

vim.api.nvim_create_user_command("InsertGenerated", function(opts)
  insert_generated(opts.args)
end, {
  nargs = 1,
  complete = function()
    return vim.tbl_map(function(item)
      return item.id
    end, generators)
  end,
  desc = "插入生成的 ID/日期值",
})

vim.keymap.set("i", "<C-g>k", pick_and_insert_generated, { desc = "打开生成值菜单" })
vim.keymap.set("i", "<C-x>1", function()
  insert_generated "uuid1"
end, { desc = "插入 UUID v1" })
vim.keymap.set("i", "<C-x>2", function()
  insert_generated "uuid2"
end, { desc = "插入 UUID v2" })
vim.keymap.set("i", "<C-x>3", function()
  insert_generated "uuid3"
end, { desc = "插入 UUID v3" })
vim.keymap.set("i", "<C-x>4", function()
  insert_generated "uuid4"
end, { desc = "插入 UUID v4" })
vim.keymap.set("i", "<C-x>5", function()
  insert_generated "uuid5"
end, { desc = "插入 UUID v5" })
vim.keymap.set("i", "<C-x>6", function()
  insert_generated "uuid6"
end, { desc = "插入 UUID v6" })
vim.keymap.set("i", "<C-x>7", function()
  insert_generated "uuid7"
end, { desc = "插入 UUID v7" })
vim.keymap.set("i", "<C-x>u", function()
  insert_generated "ulid"
end, { desc = "插入 ULID" })
vim.keymap.set("i", "<C-x>d", function()
  insert_generated "date"
end, { desc = "插入日期" })
vim.keymap.set("i", "<C-x>t", function()
  insert_generated "datetime"
end, { desc = "插入日期time" })
vim.keymap.set("i", "<C-x>i", function()
  insert_generated "datetime_iso"
end, { desc = "插入 ISO 日期时间" })
]],
		"@lua/plugins/generators.lua",
		"t",
		_ENV
	))(...)
end

package.preload["plugins.integrations.databases"] = function(...)
	return assert(load(
		[[
local pack = require "plugins.pack"

pack.add {
  { src = "https://github.com/joryeugene/dadbod-grip.nvim" },
}
require("dadbod-grip").setup { ai = false }
]],
		"@lua/plugins/integrations/databases.lua",
		"t",
		_ENV
	))(...)
end

package.preload["plugins.integrations.discord"] = function(...)
	return assert(load(
		[[
local pack = require "plugins.pack"

vim.g.cord_defer_startup = true

pack.add {
  {
    src = "https://github.com/vyfor/cord.nvim",
    update_hook = function(ev)
      if not ev.data.active then
        vim.cmd.packadd "cord.nvim"
      end
      vim.cmd "Cord update"
    end,
  },
}

local runtime_dir = vim.env.XDG_RUNTIME_DIR
if not runtime_dir and vim.uv.os_get_passwd then
  local passwd = vim.uv.os_get_passwd()
  if passwd and passwd.uid then
    runtime_dir = "/run/user/" .. passwd.uid
  end
end

if not runtime_dir then
  return
end

local ipc = runtime_dir .. "/discord-ipc-0"

if vim.fn.filereadable(ipc) == 1 then
  require("cord").setup {
    log_level = vim.log.levels.WARN,
    enabled = true,
    display = {
      theme = "catppuccin",
      flavor = "accent",
    },
    extensions = {
      visibility = {
        cache = false,
        precedence = "whitelist",
        rules = {
          whitelist = {
            "~/.config/nvim/",
          },
        },
      },
    },
  }
end
]],
		"@lua/plugins/integrations/discord.lua",
		"t",
		_ENV
	))(...)
end

package.preload["plugins.integrations.lilypond"] = function(...)
	return assert(load(
		[[
local pack = require "plugins.pack"
pack.add {
  { src = "https://github.com/martineausimon/nvim-lilypond-suite" },
  { src = "https://github.com/MunifTanjim/nui.nvim" },
}
require("nvls").setup {
  lilypond = {
    mappings = {
      player = "<leader>lp",
      compile = "<leader>lc",
      open_pdf = "<leader>lv",
    },
  },
  player = {
    options = {
      midi_synh = "timidity",
    },
  },
}
]],
		"@lua/plugins/integrations/lilypond.lua",
		"t",
		_ENV
	))(...)
end

package.preload["plugins.lsp"] = function(...)
	return assert(load(
		[[
-- Compatibility filetype registrations for lspconfig defaults on older Neovim
-- filetype tables. Without these, vim.lsp.config warns about unknown filetypes.
vim.filetype.add {
  filename = {
    ["go.work"] = "gowork",
  },
  pattern = {
    [".*/[Dd]ocker%-compose%.ya?ml"] = "yaml.docker-compose",
    [".*/compose%.ya?ml"] = "yaml.docker-compose",
    [".*%.gotmpl"] = "gotmpl",
    [".*%.go%.tmpl"] = "gotmpl",
  },
}

local pack = require "plugins.pack"

pack.add {
  { src = "https://github.com/neovim/nvim-lspconfig" },
  { src = "https://github.com/folke/lazydev.nvim" },
  { src = "https://github.com/ray-x/lsp_signature.nvim" },
  { src = "https://github.com/jmbuhr/otter.nvim" },
  { src = "https://github.com/nvim-mini/mini.snippets" },
  { src = "https://github.com/rafamadriz/friendly-snippets" },
  {
    src = "https://github.com/likec4/likec4.nvim",

    install_hook = function(ev)
      vim.notify "[likec4.nvim] npm install -g @likec4/lsp"
      vim.system({ "npm", "install", "-g", "@likec4/lsp" }, { cwd = ev.data.path }):wait()
    end,
  },
}

require("otter").setup()
local snacks = require "snacks"
vim.g.otter_enabled = false

snacks.toggle
  .new({
    id = "otter",
    name = "Embedded LSPs (otter)",
    get = function()
      return vim.g.otter_enabled
    end,
    set = function(state)
      if state then
        vim.g.otter_enabled = true
        require("otter").activate()
      else
        vim.g.otter_enabled = false
        require("otter").deactivate()
      end
    end,
  })
  :map "<leader>tl"

require("lazydev").setup()

local snippets = require "mini.snippets"

snippets.setup {
  snippets = {
    snippets.gen_loader.from_lang(),
  },
}

snippets.start_lsp_server { match = false }

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.textDocument.foldingRange = {
  dynamicRegistration = false,
  lineFoldingOnly = true,
}

local function jsonls_unusable()
  local cmd = vim.fn.exepath "vscode-json-language-server"
  if cmd == "" then
    return false
  end

  local ok, result = pcall(function()
    return vim.system({ cmd, "--version" }, { text = true }):wait(1000)
  end)
  if not ok or not result or result.code == 0 then
    return false
  end

  local output = (result.stdout or "") .. (result.stderr or "")
  return output:find("require is not defined in ES module scope", 1, true) ~= nil
    or output:find("Cannot use 'import.meta' outside a module", 1, true) ~= nil
end

---@type table<string, vim.lsp.Config|true>
local servers = {
  lua_ls = {
    filetypes = { "lua" },
  },
  ty = {
    cmd = { "uvx", "ty", "server" },
    filetypes = { "python" },
    settings = {
      ty = {
        diagnosticMode = "workspace",
      },
    },
    init_options = {
      experimental = {
        useUv = "scripts",
      },
    },
  }, -- Python
  ruff = {
    cmd = { "uvx", "ruff", "server" },
    filetypes = { "python" },
  },
  bashls = true,
  rust_analyzer = true,
  zls = true,
  taplo = true, -- TOML toolkit
  lemminx = true, -- XML
  gopls = true,
  ts_ls = true,
  docker_language_server = true,
  nixd = true,
  terraform_lsp = true,
}

if jsonls_unusable() then
  vim.notify(
    "Skipping jsonls: vscode-json-language-server crashes on startup. Update vscode-langservers-extracted to restore JSON LSP.",
    vim.log.levels.WARN
  )
else
  servers.jsonls = {
    cmd = { "vscode-json-language-server", "--stdio" },
    filetypes = { "json", "jsonc" },
  }
end

for name, spec in pairs(servers) do
  local config = spec == true and {} or vim.deepcopy(spec)
  config.capabilities = vim.tbl_deep_extend("force", vim.deepcopy(capabilities), config.capabilities or {})

  vim.lsp.config(name, config)
  vim.lsp.enable(name)
end

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    vim.o.signcolumn = "yes:1"
    local client = assert(vim.lsp.get_client_by_id(args.data.client_id))
    local bufnr = args.buf
    local filetype = vim.bo[bufnr].filetype

    -- Let injected Tree-sitter languages like JSON win inside Python strings.
    if filetype == "python" then
      client.server_capabilities.semanticTokensProvider = nil
    end

    if client:supports_method "textDocument/completion" then
      vim.o.complete = "o,.,w,b,u"
      vim.o.completeopt = "menu,menuone,popup,noinsert"
      vim.lsp.completion.enable(true, client.id, bufnr)
    end

    if client:supports_method "textDocument/inlayHint" then
      vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
    end

    vim.keymap.set("n", "grd", vim.lsp.buf.definition, {
      buffer = bufnr,
      desc = "跳转到定义",
    })

    vim.keymap.set({ "i" }, "<C-k>", function()
      require("lsp_signature").toggle_float_win()
    end, {
      buffer = bufnr,
      desc = "签名帮助",
    })
  end,
})
]],
		"@lua/plugins/lsp.lua",
		"t",
		_ENV
	))(...)
end

package.preload["plugins.navigation"] = function(...)
	return assert(load(
		[[
local pack = require "plugins.pack"

vim.keymap.set("n", "<c-h>", "<c-w><c-h>", { desc = "切换到左侧窗口", noremap = true, silent = true })
vim.keymap.set("n", "<c-j>", "<c-w><c-j>", { desc = "切换到下方窗口", noremap = true, silent = true })
vim.keymap.set("n", "<c-k>", "<c-w><c-k>", { desc = "切换到上方窗口", noremap = true, silent = true })
vim.keymap.set("n", "<c-l>", "<c-w><c-l>", { desc = "切换到右侧窗口", noremap = true, silent = true })

pack.add {
  { src = "https://github.com/folke/snacks.nvim" },
  { src = "https://github.com/folke/which-key.nvim" },
  { src = "https://github.com/nvim-neo-tree/neo-tree.nvim" },
  { src = "https://github.com/MunifTanjim/nui.nvim" },
  { src = "https://github.com/MagicDuck/grug-far.nvim" },
}

local snacks = require "snacks"
snacks.setup {
  picker = {
    enabled = true,
    ui_select = true,
    layout = {
      cycle = true,
    },
  },
}

local terminal_bufnr
local terminal_winnr

local function toggle_bottom_terminal()
  if terminal_winnr and vim.api.nvim_win_is_valid(terminal_winnr) then
    vim.api.nvim_win_close(terminal_winnr, true)
    terminal_winnr = nil
    return
  end

  if not terminal_bufnr or not vim.api.nvim_buf_is_valid(terminal_bufnr) then
    terminal_bufnr = vim.api.nvim_create_buf(false, true)
    vim.bo[terminal_bufnr].bufhidden = "hide"
    vim.api.nvim_buf_call(terminal_bufnr, function()
      vim.fn.termopen(vim.o.shell, {
        on_exit = function()
          vim.schedule(function()
            if terminal_bufnr and vim.api.nvim_buf_is_valid(terminal_bufnr) then
              vim.bo[terminal_bufnr].bufhidden = "wipe"
            end
            terminal_bufnr = nil
            terminal_winnr = nil
          end)
        end,
      })
    end)
  end

  vim.cmd "botright split"
  terminal_winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_height(terminal_winnr, math.max(8, math.floor(vim.o.lines * 0.25)))
  vim.api.nvim_win_set_buf(terminal_winnr, terminal_bufnr)
  vim.cmd "startinsert"
end

vim.keymap.set({ "n", "t" }, "<C-/>", toggle_bottom_terminal, { desc = "切换底部终端" })
vim.keymap.set({ "n", "t" }, "<C-_>", toggle_bottom_terminal, { desc = "切换底部终端" })

local picker = snacks.picker

require("grug-far").setup {}

local function git_root()
  return vim.fs.root(0, { ".git" }) or vim.uv.cwd()
end

local function open_lazygit(path)
  if vim.fn.executable "lazygit" == 0 then
    vim.notify("lazygit is not installed", vim.log.levels.ERROR)
    return
  end

  vim.cmd "tabnew"
  vim.fn.termopen({ "lazygit" }, {
    cwd = path or git_root(),
    on_exit = function()
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(0) then
          vim.cmd "bd!"
        end
      end)
    end,
  })
  vim.cmd.startinsert()
end

local function delete_other_buffers()
  local current = vim.api.nvim_get_current_buf()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if bufnr ~= current and vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].buflisted then
      vim.api.nvim_buf_delete(bufnr, {})
    end
  end
end

local function delete_current_buffer(force)
  vim.api.nvim_buf_delete(0, { force = force or false })
end

vim.keymap.set("n", "<leader>gg", function()
  open_lazygit(git_root())
end, { desc = "Lazygit（项目根目录）" })
vim.keymap.set("n", "<leader>gG", function()
  open_lazygit(vim.uv.cwd())
end, { desc = "Lazygit（当前目录）" })
vim.keymap.set("n", "<leader>gl", function()
  picker.git_log()
end, { desc = "Git 日志" })
vim.keymap.set("n", "<leader>gL", function()
  picker.git_log_line()
end, { desc = "当前行 Git 日志" })
vim.keymap.set("n", "<leader>gf", function()
  picker.git_log_file()
end, { desc = "文件 Git 历史" })

vim.keymap.set("n", "<S-h>", "<Cmd>bprevious<CR>", { desc = "上一个缓冲区" })
vim.keymap.set("n", "<S-l>", "<Cmd>bnext<CR>", { desc = "下一个缓冲区" })
vim.keymap.set("n", "[b", "<Cmd>bprevious<CR>", { desc = "上一个缓冲区" })
vim.keymap.set("n", "]b", "<Cmd>bnext<CR>", { desc = "下一个缓冲区" })
vim.keymap.set("n", "<leader>bb", "<Cmd>e #<CR>", { desc = "切换到另一个缓冲区" })
vim.keymap.set("n", "<leader>bo", delete_other_buffers, { desc = "删除其他缓冲区" })
vim.keymap.set("n", "<leader>bd", function()
  delete_current_buffer(false)
end, { desc = "删除缓冲区" })
vim.keymap.set("n", "<leader>bD", function()
  delete_current_buffer(true)
end, { desc = "删除缓冲区 (force)" })
vim.keymap.set("n", "<leader>bp", "<Cmd>bprevious<CR>", { desc = "上一个缓冲区" })
vim.keymap.set("n", "<leader>bn", "<Cmd>bnext<CR>", { desc = "下一个缓冲区" })
vim.keymap.set("n", "<leader>br", "<Cmd>edit<CR>", { desc = "重新加载缓冲区" })

vim.keymap.set({ "n", "x" }, "<leader>y", '"+y', { desc = "复制到系统剪贴板" })
vim.keymap.set("n", "<leader>Y", '"+Y', { desc = "复制整行到系统剪贴板" })

vim.keymap.set("n", "<leader>cf", function()
  require("conform").format { async = true, lsp_format = "fallback" }
end, { desc = "格式化缓冲区" })
vim.keymap.set("n", "<leader>qq", "<Cmd>qa<CR>", { desc = "退出所有窗口" })
vim.keymap.set("n", "<leader>qQ", "<Cmd>qa!<CR>", { desc = "强制退出所有窗口" })

-- search files
vim.keymap.set("n", "<leader>sf", picker.files, { desc = "搜索文件" })
vim.keymap.set("n", "<leader>sb", picker.buffers, { desc = "搜索缓冲区" })
vim.keymap.set("n", "<leader>sg", picker.git_grep, { desc = "实时 Git 搜索" })
vim.keymap.set("n", "<leader>sG", picker.grep, { desc = "实时文本搜索" })
vim.keymap.set("n", "<leader>s*", picker.grep_word, { desc = "搜索光标下的单词" })
vim.keymap.set("n", "<leader>sr", picker.resume, { desc = "恢复上次搜索" })
vim.keymap.set("n", "<leader>sn", picker.notifications, { desc = "搜索通知" })
-- finders
vim.keymap.set("n", "<leader>fk", picker.keymaps, { desc = "查找快捷键" })
vim.keymap.set("n", "<leader>fc", picker.commands, { desc = "查找命令" })
vim.keymap.set("n", "<leader>fm", picker.marks, { desc = "查找标记" })
vim.keymap.set("n", "<leader>fs", picker.spelling, { desc = "查找拼写" })
-- diagnostics
vim.keymap.set("n", "<leader>db", picker.diagnostics_buffer, { desc = "显示当前缓冲区诊断" })
vim.keymap.set("n", "<leader>da", picker.diagnostics, { desc = "显示工作区诊断" })
-- github / gh
vim.keymap.set("n", "<leader>gi", picker.gh_issue, { desc = "GitHub 问题" })
vim.keymap.set("n", "<leader>gp", picker.gh_pr, { desc = "GitHub 拉取请求" })
vim.keymap.set("n", "<leader>gs", picker.git_status, { desc = "Git 状态" })
vim.keymap.set("n", "<leader>gb", snacks.git.blame_line, { desc = "Git 行级追溯" })

snacks.toggle
  .option("conceallevel", { off = 0, on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2 })
  :map "<leader>tc"
snacks.toggle.zoom():map "<leader>tz"
snacks.toggle.diagnostics():map "<leader>td"
snacks.toggle.inlay_hints():map "<leader>th"
snacks.toggle.dim():map "<leader>tD"
snacks.toggle.option("background", { off = "light", on = "dark", name = "Dark Background" }):map "<leader>tb"
snacks.toggle
  .new({
    id = "transparent_background",
    name = "Transparent Background",
    get = function()
      return require("plugins.ui").transparent_background()
    end,
    set = function(state)
      require("plugins.ui").set_transparent_background(state)
    end,
  })
  :map "<leader>tB"
snacks.toggle.option("autocomplete", { off = false, on = true, name = "Autocomplete" }):map "<leader>ta"

require("which-key").setup {
  preset = "modern",
  spec = {
    { "<leader>b", group = "缓冲区" },
    { "<leader>c", group = "代码" },
    { "<leader>d", group = "诊断" },
    { "<leader>f", group = "文件/查找" },
    { "<leader>g", group = "版本控制" },
    { "<leader>q", group = "退出/会话" },
    { "<leader>s", group = "搜索" },
    { "<leader>t", group = "切换" },
    { "<leader>w", group = "窗口" },
    { "<leader>x", group = "诊断/快速修复" },
  },
}

require("neo-tree").setup {
  close_if_last_window = true,
  default_component_configs = {
    git_status = {
      symbols = {
        staged = "",
      },
    },
  },
  filesystem = {
    follow_current_file = { enabled = true },
    hijack_netrw_behavior = "open_default",
    use_libuv_file_watcher = true,
  },
  window = {
    mappings = {
      ["<space>"] = "none",
    },
  },
}

vim.keymap.set("n", "<leader>e", "<Cmd>Neotree toggle reveal_force_cwd<CR>", {
  silent = true,
  desc = "文件树（当前目录）",
})
vim.keymap.set("n", "<leader>E", "<Cmd>Neotree toggle reveal<CR>", {
  silent = true,
  desc = "文件树（项目根目录）",
})
vim.keymap.set("n", "<leader>fe", "<Cmd>Neotree toggle reveal<CR>", {
  silent = true,
  desc = "文件树（项目根目录）",
})
vim.keymap.set("n", "<leader>fE", "<Cmd>Neotree toggle reveal_force_cwd<CR>", {
  silent = true,
  desc = "文件树（当前目录）",
})

vim.keymap.set("n", "<leader>?", function()
  require("which-key").show { global = false }
end, { desc = "当前缓冲区快捷键" })

vim.keymap.set("n", "<leader>bd", function()
  delete_current_buffer(false)
end, { desc = "删除缓冲区" })
vim.keymap.set("n", "<leader>bn", "<Cmd>bnext<CR>", { desc = "下一个缓冲区" })
vim.keymap.set("n", "<leader>bp", "<Cmd>bprevious<CR>", { desc = "上一个缓冲区" })

vim.keymap.set("n", "<leader>sh", picker.help, { desc = "帮助页面" })
vim.keymap.set("n", "<leader>sk", picker.keymaps, { desc = "快捷键" })
vim.keymap.set("n", "<leader>sc", picker.commands, { desc = "命令" })
vim.keymap.set("n", "<leader>sw", picker.grep_word, { desc = "搜索单词" })

vim.keymap.set("n", "-", "<Cmd>Neotree toggle reveal_force_cwd<CR>", {
  silent = true,
  desc = "打开文件树",
})
]],
		"@lua/plugins/navigation.lua",
		"t",
		_ENV
	))(...)
end

package.preload["plugins.pack"] = function(...)
	return assert(load(
		[[
local M = {}

local hooks = {}
local registered = false

local function infer_name(src)
  local name = src:match("/([^/]+)%.git$") or src:match("/([^/]+)$")
  assert(name, "Cannot infer plugin name from source: " .. src)
  return name
end

local function plugin_name(spec)
  if type(spec) == "string" then
    return infer_name(spec)
  end
  return spec.name or infer_name(spec.src)
end

local function ensure_autocmd()
  if registered then
    return
  end
  registered = true

  vim.api.nvim_create_autocmd("PackChanged", {
    callback = function(ev)
      local plugin_hooks = hooks[ev.data.spec.name]
      if not plugin_hooks then
        return
      end

      local hook = plugin_hooks[ev.data.kind]
      if hook then
        hook(ev)
      end
    end,
  })
end

function M.add(specs, opts)
  ensure_autocmd()

  local pack_specs = {}

  for _, original in ipairs(specs) do
    if type(original) == "string" then
      table.insert(pack_specs, original)
    else
      local spec = vim.deepcopy(original)
      local name = plugin_name(spec)
      local plugin_hooks = {
        install = spec.install_hook,
        update = spec.update_hook,
        delete = spec.delete_hook,
      }

      spec.install_hook = nil
      spec.update_hook = nil
      spec.delete_hook = nil
      spec.confirm = nil

      if plugin_hooks.install or plugin_hooks.update or plugin_hooks.delete then
        hooks[name] = plugin_hooks
      end

      table.insert(pack_specs, spec)
    end
  end

  opts = vim.tbl_extend("force", { confirm = false }, opts or {})
  return vim.pack.add(pack_specs, opts)
end

return M
]],
		"@lua/plugins/pack.lua",
		"t",
		_ENV
	))(...)
end

package.preload["plugins.ui"] = function(...)
	return assert(load(
		[=[
local M = {}
local pack = require "plugins.pack"
local has_ui = #vim.api.nvim_list_uis() > 0
local transparent_background = true

if has_ui then
  -- require("vim._core.ui2").enable {}
end

pack.add {
  { src = "https://github.com/catppuccin/nvim", name = "catppuccin" },
  { src = "https://github.com/nvim-mini/mini.icons" },
  { src = "https://github.com/nvim-mini/mini.tabline", name = "mini.tabline" },
  { src = "https://github.com/nvim-mini/mini.statusline", name = "mini.statusline" },
  { src = "https://github.com/nvim-mini/mini-git", name = "mini.git" },
  { src = "https://github.com/nvim-mini/mini.diff", name = "mini.diff" },
  { src = "https://github.com/nvim-mini/mini.indentscope" },
  { src = "https://github.com/nvim-mini/mini.notify" },
  { src = "https://github.com/brenoprata10/nvim-highlight-colors" },
  { src = "https://github.com/lewis6991/hover.nvim" },
}

local function apply_catppuccin()
  require("catppuccin").setup {
    flavour = "auto",
    background = {
      light = "latte",
      dark = "mocha",
    },
    transparent_background = transparent_background,
  }
  vim.cmd.colorscheme "catppuccin-nvim"
end

function M.transparent_background()
  return transparent_background
end

function M.set_transparent_background(state)
  transparent_background = state
  apply_catppuccin()
  M.apply_highlights()
end

function M.apply_highlights()
  vim.api.nvim_set_hl(0, "MiniStatuslineDiagnosticError", {
    fg = "#f38ba8",
    bold = true,
  })

  local palette = require("catppuccin.palettes").get_palette()
  vim.api.nvim_set_hl(0, "HoverActiveSource", {
    fg = palette.base,
    bg = palette.mauve,
    bold = true,
  })
  vim.api.nvim_set_hl(0, "HoverInactiveSource", {
    fg = palette.overlay0,
    bg = palette.surface0,
  })
  vim.api.nvim_set_hl(0, "HoverSourceLine", {
    fg = palette.overlay0,
    bg = palette.mantle,
  })
end

apply_catppuccin()

if has_ui then
  require("mini.notify").setup()
  require("mini.icons").setup()
  require("mini.icons").tweak_lsp_kind()
  require("mini.icons").mock_nvim_web_devicons()

  require("mini.tabline").setup()
  require("mini.statusline").setup {
    content = {
      active = function()
        local mode, mode_hl = MiniStatusline.section_mode { trunc_width = 120 }
        local git = MiniStatusline.section_git { trunc_width = 40 }
        local diff = MiniStatusline.section_diff { trunc_width = 75 }
        local diagnostics = MiniStatusline.section_diagnostics { trunc_width = 75 }
        local lsp = MiniStatusline.section_lsp { trunc_width = 75 }
        local filename = MiniStatusline.section_filename { trunc_width = 140 }
        local fileinfo = MiniStatusline.section_fileinfo { trunc_width = 120 }
        local location = MiniStatusline.section_location { trunc_width = 75 }
        local search = MiniStatusline.section_searchcount { trunc_width = 75 }

        return MiniStatusline.combine_groups {
          { hl = mode_hl, strings = { mode } },
          { hl = "MiniStatuslineDevinfo", strings = { git, diff } },
          { hl = "MiniStatuslineDiagnosticError", strings = { diagnostics } },
          { hl = "MiniStatuslineDevinfo", strings = { lsp } },
          "%<",
          { hl = "MiniStatuslineFilename", strings = { filename } },
          "%=",
          { hl = "MiniStatuslineFileinfo", strings = { fileinfo } },
          { hl = mode_hl, strings = { search, location } },
        }
      end,
    },
  }
  require("mini.indentscope").setup()

  require("hover").config {
    --- List of modules names to load as providers.
    providers = {
      "hover.providers.diagnostic",
      "hover.providers.lsp",
      "hover.providers.dap",
      "hover.providers.man",
      "hover.providers.dictionary",
      -- Optional, disabled by default:
      -- 'hover.providers.gh',
      -- 'hover.providers.gh_user',
      -- 'hover.providers.jira',
      -- 'hover.providers.fold_preview',
      -- 'hover.providers.highlight',
    },
    mouse_providers = {
      -- "hover.providers.lsp",
    },
  }
  M.apply_highlights()
  -- Setup keymaps
  vim.keymap.set("n", "K", function()
    require("hover").open()
  end, { desc = "打开悬浮提示" })
end

require("mini.git").setup()
require("mini.diff").setup()

require("nvim-highlight-colors").setup {
  render = "virtual",
  virtual_symbol = "⚫︎",
  virtual_symbol_suffix = "",
}

if has_ui then
  vim.cmd [[
    aunmenu PopUp
    autocmd! nvim.popupmenu
  ]]
end

-- inline diagnostic
pack.add {
  { src = "https://github.com/rachartier/tiny-inline-diagnostic.nvim" },
}
require("tiny-inline-diagnostic").setup {
  options = {
    multilines = { enabled = true },
    show_source = { enabled = true },
    override_open_float = true,
  },
}
vim.diagnostic.config { virtual_text = false } -- Disable Neovim's default virtual text diagnostics

vim.keymap.set("n", "<leader>de", "<cmd>TinyInlineDiag enable<cr>", { desc = "启用诊断" })
vim.keymap.set("n", "<leader>dd", "<cmd>TinyInlineDiag disable<cr>", { desc = "禁用诊断" })
vim.keymap.set("n", "<leader>dt", "<cmd>TinyInlineDiag toggle<cr>", { desc = "切换诊断" })
vim.keymap.set(
  "n",
  "<leader>dc",
  "<cmd>TinyInlineDiag toggle_cursor_only<cr>",
  { desc = "切换仅显示光标处诊断" }
)
vim.keymap.set("n", "<leader>dr", "<cmd>TinyInlineDiag reset<cr>", { desc = "重置诊断选项" })

-- folding rules
pack.add {
  { src = "https://github.com/kevinhwang91/nvim-ufo" },
  { src = "https://github.com/kevinhwang91/promise-async" },
}

vim.o.foldcolumn = "1" -- '0' is not bad
vim.o.foldlevel = 99 -- Using ufo provider need a large value, feel free to decrease the value
vim.o.foldlevelstart = 99
vim.o.foldenable = true

require("ufo").setup {
  enable_get_fold_virt_text = true,
  provider_selector = function(bufnr, filetype, buftype)
    return { "treesitter", "indent" }
  end,
  open_fold_hl_timeout = 150,
  close_fold_kinds_for_ft = {
    default = { "imports", "comment" },
    json = { "array" },
    c = { "comment", "region" },
    python = { "import_statement", "import_from_statement", "comment" },
  },
  close_fold_current_line_for_ft = {
    default = true,
    c = false,
  },
}
vim.o.fillchars = "eob: ,fold: ,foldopen:,foldsep: ,foldclose:"
vim.keymap.set("n", "zR", require("ufo").openAllFolds)
vim.keymap.set("n", "zM", require("ufo").closeAllFolds)
vim.keymap.set("n", "zr", require("ufo").openFoldsExceptKinds)
vim.keymap.set("n", "zm", require("ufo").closeFoldsWith) -- closeAllFolds == closeFoldsWith(0)
vim.keymap.set("n", "zk", function()
  require("ufo").peekFoldedLinesUnderCursor()
end)

return M
]=],
		"@lua/plugins/ui.lua",
		"t",
		_ENV
	))(...)
end

-- init.lua
assert(load(
	[[
if vim.version.ge(vim.version(), { 0, 12, 0 }) then
  require "plugins.core"
  require "plugins.ui"
  require "plugins.editing"
  require "plugins.generators"
  require "plugins.navigation"
  require "plugins.lsp"
  require "plugins.integrations.discord"
  require "plugins.integrations.databases"
  require "plugins.integrations.lilypond"
else
  local v = vim.version()
  vim.notify("Skip config, neovim >= 0.12.0 is required. This is " .. v.major .. "." .. v.minor .. "." .. v.patch)
end
]],
	"@init.lua",
	"t",
	_ENV
))()

-- plugin/*.lua

-- after/plugin/*.lua

-- ftplugin hooks
vim.api.nvim_create_autocmd("FileType", {
	pattern = "oil",
	group = vim.api.nvim_create_augroup("compact_ftplugin_ftplugin_oil", { clear = true }),
	callback = function(args) end,
})

-- after/ftplugin hooks
