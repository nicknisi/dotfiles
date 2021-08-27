local nnoremap = require("utils").nnoremap

local view = require("nvim-tree.view")
_G.NvimTreeConfig = {}

vim.g.nvim_tree_follow = 1

vim.g.nvim_tree_icons = {
  default = "",
  symlink = "",
  git = {
    unstaged = "●",
    staged = "✓",
    unmerged = "",
    renamed = "➜",
    untracked = "★",
    deleted = "",
    ignored = "◌"
  },
  folder = {
    arrow_open = "",
    arrow_closed = "",
    default = "",
    open = "",
    empty = "",
    empty_open = "",
    symlink = "",
    symlink_open = ""
  },
  lsp = {
    hint = "",
    info = "",
    warning = "",
    error = ""
  }
}

function NvimTreeConfig.find_toggle()
  if view.win_open() then
    view.close()
  else
    vim.cmd("NvimTreeFindFile")
  end
end

nnoremap("<leader>k", "<CMD>lua NvimTreeConfig.find_toggle()<CR>")

view.width = 40
