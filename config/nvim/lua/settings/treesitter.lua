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
  playground = {
    enable = true,
    disable = {},
    updatetime = 25,
    persist_queries = false,
    keybindings = {
      toggle_query_editor = "o",
      toggle_hl_groups = "i",
      toggle_injected_languages = "t",
      toggle_anonymous_nodes = "a",
      toggle_language_display = "I",
      focus_language = "f",
      unfocus_language = "F",
      update = "R",
      goto_node = "<cr>",
      show_help = "?"
    }
  }
}
