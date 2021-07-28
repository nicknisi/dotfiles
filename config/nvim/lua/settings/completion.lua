local utils = require("utils")
local imap = utils.imap
local smap = utils.smap
local api = vim.api
local fn = vim.fn

-- use .ts snippets in .tsx files
vim.o.completeopt = "menuone,noselect"

vim.g.vsnip_filetypes = {
  typescriptreact = {"typescript"}
}
require("compe").setup {
  preselect = "always",
  source = {
    path = true,
    buffer = true,
    vsnip = true,
    nvim_lsp = true,
    nvim_lua = true
  }
}
local t = function(str)
  return vim.api.nvim_replace_termcodes(str, true, true, true)
end
_G.tab_complete = function()
  if vim.fn.pumvisible() == 1 then
    return vim.fn["compe#confirm"]()
  elseif vim.fn.call("vsnip#available", {1}) == 1 then
    return t("<Plug>(vsnip-expand-or-jump)")
  else
    return t("<Tab>")
  end
end
imap("<Tab>", [[v:lua.tab_complete()]], {expr = true})
smap("<Tab>", [[v:lua.tab_complete()]], {expr = true})
imap("<C-Space>", [[compe#complete()]], {expr = true})
imap("<CR>", [[compe#confirm('<CR>')]], {expr = true})
imap("<C-e>", [[compe#close('<C-e>')]], {expr = true})

-- lspkind configuration
require("lspkind").init(
  {
    with_text = false
  }
)
