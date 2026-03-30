local config = require("nisi").config
return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    version = false,
    event = { "BufReadPost", "BufNewFile" },
    dependencies = {
      "nvim-treesitter/playground",
      "nvim-treesitter/nvim-treesitter-textobjects",
      "JoosepAlviste/nvim-ts-context-commentstring",
    },
    init = function(plugin)
      if config.prefer_git then
        require("nvim-treesitter.install").prefer_git = true
      end
      require("lazy.core.loader").add_to_rtp(plugin)
      require("nvim-treesitter.query_predicates")

      -- nvim 0.12: match[capture_id] is now always TSNode[] (list), not TSNode.
      -- Re-register the directives that nvim-treesitter registers with the old
      -- single-node assumption so they unwrap the list first.
      if vim.fn.has("nvim-0.12") == 1 then
        local tsquery = require("vim.treesitter.query")

        local function unwrap(match, capture_id)
          local node = match[capture_id]
          if type(node) == "table" then
            return node[1]
          end
          return node
        end

        local non_ft_aliases = {
          ex = "elixir", pl = "perl", sh = "bash",
          uxn = "uxntal", ts = "typescript",
        }
        local html_types = {
          ["importmap"] = "json", ["module"] = "javascript",
          ["application/ecmascript"] = "javascript",
          ["text/ecmascript"] = "javascript",
        }

        local function info_string_to_lang(alias)
          local match = vim.filetype.match({ filename = "a." .. alias })
          return match or non_ft_aliases[alias] or alias
        end

        tsquery.add_directive("set-lang-from-info-string!", function(match, _, bufnr, pred, metadata)
          local node = unwrap(match, pred[2])
          if not node then return end
          metadata["injection.language"] = info_string_to_lang(
            vim.treesitter.get_node_text(node, bufnr):lower()
          )
        end, { force = true })

        tsquery.add_directive("set-lang-from-mimetype!", function(match, _, bufnr, pred, metadata)
          local node = unwrap(match, pred[2])
          if not node then return end
          local text = vim.treesitter.get_node_text(node, bufnr)
          local configured = html_types[text]
          if configured then
            metadata["injection.language"] = configured
          else
            local parts = vim.split(text, "/", {})
            metadata["injection.language"] = parts[#parts]
          end
        end, { force = true })

        tsquery.add_directive("downcase!", function(match, _, bufnr, pred, metadata)
          local node = unwrap(match, pred[2])
          if not node then return end
          metadata["injection.language"] = vim.treesitter.get_node_text(node, bufnr):lower()
        end, { force = true })
      end
      local parser_config = require("nvim-treesitter.parsers").get_parser_configs()
      parser_config.blade = {
        install_info = {
          url = "https://github.com/EmranMR/tree-sitter-blade",
          files = { "src/parser.c" },
          branch = "main",
        },
        filetype = "blade",
      }

      vim.filetype.add({
        pattern = {
          [".*%.blade%.php"] = "blade",
        },
      })
    end,
    config = function(_, opts)
      require("nvim-treesitter.configs").setup(opts)
      vim.treesitter.language.register("markdown", { "md", "mdx" })
    end,
    opts = {
      ensure_installed = {
        "astro",
        "bash",
        "blade",
        "c",
        "comment",
        "cpp",
        "css",
        "diff",
        "elixir",
        "eex",
        "heex",
        "git_rebase",
        "gitcommit",
        "gitignore",
        "html",
        "javascript",
        "jsdoc",
        "json",
        "json5",
        "jsonc",
        "lua",
        "markdown",
        "markdown_inline",
        "pug",
        "python",
        "regex",
        "ruby",
        "rust",
        "tsx",
        "typescript",
        "vim",
        "yaml",
      },
      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = "gnn",
          node_incremental = "grn",
          scope_incremental = "grc",
          node_decremental = "grm",
        },
      },
      highlight = { enable = true, use_languagetree = true },
      indent = { enable = true },
      rainbow = { enable = true, extended_mode = true, max_file_lines = 1000 },
      textobjects = {
        select = {
          enable = true,
          lookahead = true, -- automatically jump forward to matching textobj
          keymaps = {
            ["af"] = "@function.outer",
            ["if"] = "@function.inner",
            ["ac"] = "@class.outer",
            ["ic"] = "@class.inner",
          },
        },
        swap = {
          enable = false,
          swap_next = { ["<leader>a"] = "@parameter.inner" },
          swap_previous = { ["<leader>A"] = "@parameter.inner" },
        },
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
          show_help = "?",
        },
      },
    },
  },
}
