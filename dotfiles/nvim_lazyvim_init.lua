-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

vim.opt.spell = false

vim.api.nvim_create_autocmd("FileType", {
  pattern = "*",
  callback = function()
    vim.opt_local.spell = false
  end,
})
