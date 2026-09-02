return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    version = false,
    event = { "BufReadPost", "BufNewFile" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter-textobjects",
      "JoosepAlviste/nvim-ts-context-commentstring",
    },
    init = function()
      vim.filetype.add({
        pattern = {
          [".*%.blade%.php"] = "blade",
        },
      })

      -- Custom parsers are registered via a `User TSUpdate` autocmd now
      vim.api.nvim_create_autocmd("User", {
        pattern = "TSUpdate",
        callback = function()
          require("nvim-treesitter.parsers").blade = {
            install_info = {
              url = "https://github.com/EmranMR/tree-sitter-blade",
              files = { "src/parser.c" },
              branch = "main",
            },
            filetype = "blade",
          }
        end,
      })
    end,
    config = function()
      -- Rewritten main branch: the old module system (configs.setup,
      -- incremental_selection, playground, rainbow) is gone. Highlighting and
      -- injections are core Neovim; the plugin now installs parsers/queries.
      local ensure_installed = {
        "astro", "bash", "blade", "c", "comment", "cpp", "css", "diff",
        "elixir", "eex", "heex", "git_rebase", "gitcommit", "gitignore",
        "html", "javascript", "jsdoc", "json", "json5", "lua", "markdown",
        "markdown_inline", "pug", "python", "regex", "ruby", "rust", "tsx",
        "typescript", "vim", "yaml",
      }
      local available = require("nvim-treesitter").get_available()
      require("nvim-treesitter").install(vim.tbl_filter(function(p)
        return vim.tbl_contains(available, p)
      end, ensure_installed))

      -- Highlighting + treesitter indent for any filetype with a parser
      vim.api.nvim_create_autocmd("FileType", {
        callback = function(args)
          if pcall(vim.treesitter.start, args.buf) then
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
      vim.treesitter.language.register("markdown", { "md", "mdx" })

      -- Textobjects keymaps are defined by the plugin itself now
      require("nvim-treesitter-textobjects").setup({ select = { lookahead = true } })
      local select = require("nvim-treesitter-textobjects.select")
      for lhs, obj in pairs({
        ["af"] = "@function.outer",
        ["if"] = "@function.inner",
        ["ac"] = "@class.outer",
        ["ic"] = "@class.inner",
      }) do
        vim.keymap.set({ "x", "o" }, lhs, function()
          select.select_textobject(obj, "textobjects")
        end, { silent = true })
      end
    end,
  },
}
