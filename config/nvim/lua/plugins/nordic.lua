return {
  {
    "AlexvZyl/nordic.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("nordic").setup({
        override = {
          Visual = {
            bg = "#3A515D",
          },
        },
        bold_keywords = true,
        italic_comments = true,
        transparent_bg = true,
        noice = { style = "flat" },
        telescope = { style = "flat" },
      })
    end,
  },
}
