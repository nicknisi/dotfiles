local view = require("nvim-tree.view")
_G.NvimTreeConfig = {}

function NvimTreeConfig.find_toggle()
  if view.win_open() then
    view.close()
  else
    vim.cmd("NvimTreeFindFile")
  end
end

vim.api.nvim_set_keymap(
  "n",
  "<leader>k",
  "<CMD>lua NvimTreeConfig.find_toggle()<CR>",
  {
    noremap = true,
    silent = true
  }
)

view.width = 40
