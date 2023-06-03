local theme = require("theme")
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  "mattn/emmet-vim", -- easy commenting
  "tpope/vim-commentary", -- bracket mappings for moving between buffers, quickfix items, etc.
  "tpope/vim-unimpaired",
  -- mappings to easily delete, change and add such surroundings in pairs, such as quotes, parens, etc.
  "tpope/vim-surround", -- endings for html, xml, etc. - ehances surround
  "tpope/vim-ragtag", -- substitution and abbreviation helpers
  "tpope/vim-abolish", -- enables repeating other supported plugins with the . command
  "tpope/vim-repeat",
  -- single/multi line code handler: gS - split one line into multiple, gJ - combine multiple lines into one
  "AndrewRadev/splitjoin.vim",
  { "junegunn/goyo.vim", keys = { { "<leader>w", "<cmd>Goyo<cr>" } } },
  -- detect indent style (tabs vs. spaces)
  "tpope/vim-sleuth", -- setup editorconfig
  "editorconfig/editorconfig-vim", -- fugitive
  {
    "tpope/vim-fugitive",
    lazy = false,
    keys = {
      { "<leader>gr", "<cmd>Gread<cr>", desc = "read file from git" },
      { "<leader>gb", "<cmd>G blame<cr>", desc = "read file from git" },
    },
    dependencies = { "tpope/vim-rhubarb" },
  }, -- general plugins
  -- match tags in html, similar to paren support
  { "gregsexton/MatchTag", ft = "html" }, -- html5 support
  { "othree/html5.vim", ft = "html" }, -- pug / jade support
  { "digitaltoad/vim-pug", ft = { "jade", "pug" } }, -- nunjucks support
  {
    "wuelnerdotexe/vim-astro",
    config = function()
      vim.cmd([[let g:astro_typescript = 'enable']])
    end,
  },
  -- Plug "niftylettuce/vim-jinja"
  { "Glench/Vim-Jinja2-Syntax", ft = { "jinja", "nunjucks" } }, -- edit quickfix list
  { "itchyny/vim-qfedit", event = "VeryLazy" }, -- liquid support
  "tpope/vim-liquid",
  { "othree/yajs.vim", ft = { "javascript", "javascript.jsx", "html", "typescript", "typescriptreact" } },
  -- Plug 'pangloss/vim-javascript', { 'for': ['javascript', 'javascript.jsx', 'html'] }
  { "moll/vim-node", ft = { "javascript", "typescript" } },
  {
    "MaxMEllon/vim-jsx-pretty",
    config = function()
      vim.g.vim_jsx_pretty_highlight_close_tag = 1
    end,
  },
  { "dmmulroy/tsc.nvim", config = true },
  { "leafgarland/typescript-vim", ft = { "typescript", "typescript.tsx" } },
  { "wavded/vim-stylus", ft = { "stylus", "markdown" } },
  { "jxnblk/vim-mdx-js", ft = "mdx" },
  { "groenewege/vim-less", ft = "less" },
  { "hail2u/vim-css3-syntax", ft = "css" },
  { "cakebaker/scss-syntax.vim", ft = "scss" },
  { "stephenway/postcss.vim", ft = "css" },
  { "udalov/kotlin-vim", ft = "kotlin" },
  {
    "elzr/vim-json",
    ft = "json",
    config = function()
      vim.g.vim_json_syntax_conceal = 0
    end,
  },
  { "ekalinin/Dockerfile.vim", ft = "Dockerfile" },
  "jparise/vim-graphql",
  { "preservim/vim-markdown", ft = "markdown", dependencies = { "godlygeek/tabular" } },
  {
    "hrsh7th/vim-vsnip",
    config = function()
      local snippet_dir = os.getenv("DOTFILES") .. "/config/nvim/snippets"
      vim.g.vsnip_snippet_dir = snippet_dir
      vim.g.vsnip_filetypes = {
        javascriptreact = { "javascript" },
        typescriptreact = { "typescript" },
        ["typescript.tsx"] = { "typescript" },
      }
    end,
  },
  "hrsh7th/cmp-vsnip",
  "hrsh7th/vim-vsnip-integ", -- add color highlighting to hex values
  {
    "NvChad/nvim-colorizer.lua",
    config = function()
      require("colorizer").setup({
        filetypes = { "*" },
        user_default_options = {
          mode = "background",
          tailwind = true,
          RGB = true,
          RRGGBB = true,
          names = true,
          RRGGBBAA = true,
          rgb_fn = true,
          hsl_fn = true,
          css = true,
          css_fn = true,
        },
      })
    end,
  },
  -- use devicons for filetypes
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v2.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
      {
        "s1n7ax/nvim-window-picker",
        -- tag = "v1.*",
        config = function()
          require("window-picker").setup({
            autoselect_one = true,
            include_current = false,
            filter_rules = {
              bo = {
                filetype = { "nep-tree", "neo-tree-popup", "notify" },
                buftype = { "terminal", "quickfix" },
              },
            },
            border = { style = "rounded", highlight = "Normal" },
            other_win_hl_color = "#e35e4f",
          })
        end,
      },
    },
  },
  "nvim-tree/nvim-web-devicons", -- fast lau file drawer
  { "kyazdani42/nvim-tree.lua" }, -- Show git information in the gutter
  { "lewis6991/gitsigns.nvim" },
  {
    "williamboman/mason.nvim",
    dependencies = {
      "williamboman/mason-lspconfig.nvim",
      "jose-elias-alvarez/null-ls.nvim",
      "jay-babu/mason-null-ls.nvim",
    },
  },
  {
    "neovim/nvim-lspconfig",
    lazy = false,
    dependencies = {
      -- Helpers to install LSPs and maintain them
      "mason.nvim",
      "williamboman/mason-lspconfig.nvim",
    },
  },
  -- neovim completion
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-nvim-lua",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "zbirenbaum/copilot-cmp",
      { "roobert/tailwindcss-colorizer-cmp.nvim", config = true },
    },
  },
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    build = ":Copilot auth",
    event = "InsertEnter",
    opts = {
      suggestion = {
        enabled = true,
        auto_trigger = true,
        keymap = {
          accept = "<Tab>",
          close = "<Esc>",
          next = "<C-J>",
          prev = "<C-K>",
          select = "<CR>",
          dismiss = "<C-X>",
        },
      },
      panel = {
        enabled = false,
      },
    },
  },
  {
    "zbirenbaum/copilot-cmp",
    config = function()
      require("copilot_cmp").setup()
    end,
  },
  -- treesitter enables an AST-like understanding of files
  {
    "axkirillov/hbac.nvim",
    config = function()
      require("hbac").setup()
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    dependencies = {
      -- show treesitter nodes
      "nvim-treesitter/playground", -- enable more advanced treesitter-aware text objects
      "nvim-treesitter/nvim-treesitter-textobjects", -- add rainbow highlighting to parens and brackets
      "p00f/nvim-ts-rainbow",
      "JoosepAlviste/nvim-ts-context-commentstring",
    },
  },
  -- show nerd font icons for LSP types in completion menu
  "onsails/lspkind-nvim", -- status line plugin
  "nvim-lualine/lualine.nvim",
  { "windwp/nvim-autopairs", config = true },
  -- Style the tabline without taking over how tabs and buffers work in Neovim
  { "alvarosevilla95/luatab.nvim", config = true }, -- enable copilot support for Neovim
  { "MunifTanjim/nui.nvim", lazy = true },
  {
    "rcarriga/nvim-notify",
    keys = {
      {
        "<leader>un",
        function()
          require("notify").dismiss({ silent = true, pending = true })
        end,
        desc = "Dismiss all Notifications",
      },
    },
    opts = {
      timeout = 3000,
      max_height = function()
        return math.floor(vim.o.lines * 0.75)
      end,
      max_width = function()
        return math.floor(vim.o.columns * 0.75)
      end,
      background_colour = "#1e222a",
      render = "minimal",
    },
    init = function()
      vim.notify = require("notify")
    end,
  },
  -- improve the default neovim interfaces, such as refactoring
  { "stevearc/dressing.nvim", event = "VeryLazy" }, -- Navigate a code base with a really slick UI
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim", -- Power telescope with FZF
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
      "nvim-telescope/telescope-rg.nvim",
      "nvim-telescope/telescope-node-modules.nvim",
    },
  },
  -- Startup screen for Neovim
  { "startup-nvim/startup.nvim" }, -- fzf
  { "junegunn/fzf.vim", dependencies = { { dir = vim.env.HOMEBREW_PREFIX .. "/opt/fzf" } } },
  { "folke/neodev.nvim", config = true },
  {
    "folke/trouble.nvim",
    config = true,
    keys = {
      { "<leader>xx", "<cmd>TroubleToggle<cr>" },
      { "<leader>xw", "<cmd>TroubleToggle workspace_diagnostics<cr>" },
      { "<leader>xd", "<cmd>TroubleToggle document_diagnostics<cr>" },
      { "<leader>xq", "<cmd>TroubleToggle quickfix<cr>" },
      { "<leader>xl", "<cmd>TroubleToggle loclist<cr>" },
    },
  },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
  },
  { "b0o/incline.nvim", opts = { hide = { cursorline = false, focused_win = false, only_win = true } } },
}, { ui = { border = theme.border } })
