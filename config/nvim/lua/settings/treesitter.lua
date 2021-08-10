require("nvim-treesitter.configs").setup {
  ensure_installed = "maintained",
  highlight = {
    enable = true,
    use_languagetree = true
  },
  indent = {enable = true},
  content_commentstring = {enable = true},
  rainbow = {
    enable = false,
    extended_mode = true,
    max_file_lines = 1000
  },
  autotag = {
    enable = true,
    filetypes = {
      "html",
      "javascript",
      "javascriptreact",
      "typescript",
      "typescriptreact"
    }
  }
}
