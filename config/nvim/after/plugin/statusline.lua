require("lualine").setup({
  options = {
    icons_enabled = true,
    theme = "catppuccin",
    section_separators = { right = "", left = "" },
    component_separators = "", --{ right = "", left = "" },
  },
  sections = {
    lualine_a = { "mode" },
    lualine_b = {
      "branch",
      { "diff", symbols = { added = " ", modified = " ", removed = "󰮉 " } },
      "diagnostics",
    },
    lualine_c = { "filename", "searchcount" },
    lualine_x = { "fileformat", "filetype" },
    lualine_y = { "progress" },
    lualine_z = { "location" },
  },
})
