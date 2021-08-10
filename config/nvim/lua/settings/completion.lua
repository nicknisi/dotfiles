local utils = require("utils")
local imap = utils.imap
local smap = utils.smap
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
    calc = true,
    nvim_lsp = true,
    nvim_lua = true,
    vsnip = true,
    ultisnips = true
  }
}

local check_back_space = function()
  local col = fn.col(".") - 1
  if col == 0 or fn.getline("."):sub(col, col):match("%s") then
    return true
  else
    return false
  end
end

local t = function(str)
  return vim.api.nvim_replace_termcodes(str, true, true, true)
end

_G.tab_complete = function()
  if vim.fn.pumvisible() == 1 then
    return t("<C-n>")
  elseif vim.fn["vsnip#available"](1) == 1 then
    return t("<Plug>(vsnip-expand-or-jump)")
  elseif vim.fn["UltiSnips#CanExpandSnippet"]() == 1 or vim.fn["UltiSnips#CanJumpForwards"]() == 1 then
    return vim.api.nvim_replace_termcodes("<C-R>=UltiSnips#ExpandSnippetOrJump()<CR>", true, true, true)
  elseif check_back_space() then
    return t("<Tab>")
  else
    return fn["compe#complete"]()
  end
end

_G.s_tab_complete = function()
  if vim.fn.pumvisible() == 1 then
    return t("<C-p>")
  elseif vim.fn["vsnip#jumpable"](-1) == 1 then
    return t("<Plug>(vsnip-jump-prev")
  elseif vim.fn["UltiSnips#CanJumpBackwards"]() == 1 then
    return vim.api.nvim_replace_termcodes("<C-R>=UltiSnips#JumpBackwards()<CR>", true, true, true)
  else
    return t("<S-Tab>")
  end
end

imap("<Tab>", [[v:lua.tab_complete()]], {expr = true})
imap("<S-Tab>", [[v:lua.s_tab_complete()]], {expr = true})
smap("<Tab>", [[v:lua.tab_complete()]], {expr = true})
smap("<S-Tab>", [[v:lua.s_tab_complete()]], {expr = true})
imap("<C-Space>", [[compe#complete()]], {expr = true})
imap("<CR>", [[compe#confirm('<CR>')]], {expr = true})
imap("<C-e>", [[compe#close('<C-e>')]], {expr = true})

-- lspkind configuration
require("lspkind").init(
  {
    with_text = false
  }
)
