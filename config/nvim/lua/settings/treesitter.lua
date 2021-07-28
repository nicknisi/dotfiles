local ts = require("nvim-treesitter.configs")

ts.setup(
  {
    ensure_installed = "maintained",
    highlight = {
      enable = true,
      use_languagetree = true
    }
  }
)
