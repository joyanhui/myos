vim.g.mapleader = " "
vim.g.maplocalleader = " "

local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.signcolumn = "yes"
opt.wrap = false
opt.scrolloff = 6
opt.sidescrolloff = 8
opt.termguicolors = true
opt.mouse = "a"
opt.clipboard = "unnamedplus"
opt.updatetime = 300
opt.timeoutlen = 400
opt.splitright = true
opt.splitbelow = true

opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.softtabstop = 2
opt.smartindent = true
opt.autoindent = true

opt.ignorecase = true
opt.smartcase = true
opt.incsearch = true
opt.hlsearch = true

opt.undofile = true
opt.undodir = vim.fn.stdpath("data") .. "/undo"
opt.swapfile = false
opt.backup = false

vim.fn.mkdir(opt.undodir:get()[1], "p")

opt.list = true
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
opt.fillchars = { eob = " " }

pcall(vim.cmd.colorscheme, "habamax")

local function map(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { silent = true, desc = desc })
end

map("n", "<leader>w", "<cmd>write<cr>", "保存")
map("n", "<leader>q", "<cmd>quit<cr>", "退出")
map("n", "<leader>x", "<cmd>xit<cr>", "保存并退出")
map("n", "<leader>h", "<cmd>nohlsearch<cr>", "清除搜索高亮")

map("n", "<leader>sv", "<cmd>vsplit<cr>", "垂直分屏")
map("n", "<leader>sh", "<cmd>split<cr>", "水平分屏")
map("n", "<C-h>", "<C-w>h", "切到左窗")
map("n", "<C-j>", "<C-w>j", "切到下窗")
map("n", "<C-k>", "<C-w>k", "切到上窗")
map("n", "<C-l>", "<C-w>l", "切到右窗")
map("n", "<C-Up>", "<cmd>resize +2<cr>", "加高")
map("n", "<C-Down>", "<cmd>resize -2<cr>", "减高")
map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", "变窄")
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", "变宽")

map("n", "<S-l>", "<cmd>bnext<cr>", "下一个缓冲区")
map("n", "<S-h>", "<cmd>bprevious<cr>", "上一个缓冲区")
map("n", "<leader>bd", "<cmd>bdelete<cr>", "关闭缓冲区")

map("v", "J", ":m '>+1<cr>gv=gv", "下移选中行")
map("v", "K", ":m '<-2<cr>gv=gv", "上移选中行")
map("v", "<", "<gv", "减少缩进")
map("v", ">", ">gv", "增加缩进")

map("n", "<Esc>", "<cmd>nohlsearch<cr><Esc>", "取消高亮")

vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.hl.on_yank({ timeout = 150 })
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "yaml", "json", "html", "css", "lua" },
  callback = function()
    vim.opt_local.shiftwidth = 2
    vim.opt_local.tabstop = 2
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "python", "go", "rust", "c", "cpp" },
  callback = function()
    vim.opt_local.shiftwidth = 4
    vim.opt_local.tabstop = 4
  end,
})
