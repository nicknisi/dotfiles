local lsp_utils = require("nisi.plugins.lsp.utils")
local make_conf = lsp_utils.make_conf
local lspconfig = require("lspconfig")
local mason = require("mason")
local mason_lspconfig = require("mason-lspconfig")
local utils = require("nisi.utils")
local fn = utils.fn
local border = "rounded"
local servers = {
  "eslint",
  "elixirls",
  "ts_ls",
  "lua_ls",
  "denols",
  "astro",
  "gopls",
  "intelephense",
  "tailwindcss",
  "jsonls",
  "ruby_lsp",
  "pylsp",
  "vimls",
}

local M = {}

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("UserLspConfig", {}),
  callback = function(ev)
    vim.api.nvim_buf_create_user_command(ev.buf, "OR", lsp_utils.lsp_organize_imports, {})

    local function map(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = ev.buf, desc = desc, silent = true })
    end

    map("n", "gO", lsp_utils.lsp_organize_imports, "Organize imports")
    map("n", "gd", vim.lsp.buf.definition, "Go to definition")
    map("n", "gD", vim.lsp.buf.declaration, "Go to declaration")
    map("n", "go", vim.lsp.buf.type_definition, "Go to type definition")
    map("n", "gr", vim.lsp.buf.rename, "Rename")
    map("n", "gR", vim.lsp.buf.references, "Show references")
    map("n", "gy", vim.lsp.buf.type_definition, "Go to type definition")
    map("n", "K", vim.lsp.buf.hover, "Show hover")
    map("n", "S", vim.lsp.buf.signature_help, "Show signature")
    map("n", "ga", vim.lsp.buf.code_action, "Show LSP code actions")
    map("v", "ga", vim.lsp.buf.code_action, "Show LSP code actions")
    map("n", "<RightMouse>", "<cmd>:popup mousemenu<cr>", "Show context menu")

    if vim.lsp.inlay_hint then
      map("n", "<Leader>hh", function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
      end, "Toggle inlay [h]ints")
    end

    map("n", "<C-x><C-x>", vim.lsp.buf.signature_help, "Show signature help")

    -- set up mousemenu options for lsp
    vim.cmd([[:amenu 10.100 mousemenu.Goto\ Definition <cmd>Telescope lsp_definitions<cr>]])
    vim.cmd([[:amenu 10.110 mousemenu.References <cmd>Telescope lsp_references<cr>]])
    vim.cmd([[:amenu 10.120 mousemenu.Implementation <cmd>Telescope lsp_implementations<cr>]])
  end,
})

function M.setup()
  -- Set diagnostic keymaps globally
  vim.keymap.set("n", "<leader>aa", lsp_utils.lsp_show_diagnostics, { desc = "Show diagnostics" })
  vim.keymap.set("n", "[d", fn(vim.diagnostic.jump, { count = -1 }), { desc = "Go to previous diagnostic" })
  vim.keymap.set("n", "]d", fn(vim.diagnostic.jump, { count = 1 }), { desc = "Go to next diagnostic" })
  vim.keymap.set("n", "<leader>aq", vim.diagnostic.setloclist, { desc = "Send diagnostics to loclist" })

  mason.setup({ ui = { border = border } })

  mason_lspconfig.setup({
    ensure_installed = servers,
    automatic_installation = true,
    ui = { check_outdated_servers_on_open = true },
  })

  local handlers = {
    function(server_name)
      lspconfig[server_name].setup(make_conf({}))
    end,
  }

  if utils.exists_in_table(servers, "eslint_d") then
    handlers["eslint"] = function()
      lspconfig.eslint.setup({
        root_dir = require("lspconfig/util").root_pattern(
          "eslint.config.js",
          "eslint.config.mjs",
          ".eslintrc.js",
          ".eslintrc.json",
          ".eslintrc"
        ),
      })
    end
  end

  if utils.exists_in_table(servers, "tailwindcss") then
    handlers["tailwindcss"] = function()
      lspconfig.tailwindcss.setup(make_conf({
        root_dir = require("lspconfig/util").root_pattern(
          "tailwind.config.js",
          "tailwind.config.ts",
          "tailwind.config.cjs"
        ),
        init_options = {
          userLanguages = {
            elixir = "html-eex",
            eelixir = "html-eex",
            heex = "html-eex",
          },
        },
        settings = {
          tailwindCSS = {
            lint = {
              cssConflict = "warning",
              invalidApply = "error",
              invalidConfigPath = "error",
              invalidScreen = "error",
              invalidTailwindDirective = "error",
              recommendedVariantOrder = "warning",
              unusedClass = "warning",
            },
            experimental = {
              -- classRegex = {
              --   "tw`([^`]*)",
              --   'tw="([^"]*)',
              --   'tw={"([^"}]*)',
              --   "tw\\.\\w+`([^`]*)",
              --   "tw\\(.*?\\)`([^`]*)",

              --   "cn`([^`]*)",
              --   'cn="([^"]*)',
              --   'cn={"([^"}]*)',
              --   "cn\\.\\w+`([^`]*)",
              --   "cn\\(.*?\\)`([^`]*)",

              --   { "clsx\\(([^)]*)\\)", "(?:'|\"|`)([^']*)(?:'|\"|`)" },
              --   { "classnames\\(([^)]*)\\)", "'([^']*)'" },
              --   { "cva\\(([^)]*)\\)", "[\"'`]([^\"'`]*).*?[\"'`]" },
              --   "cva\\(([^)(]*(?:\\([^)(]*(?:\\([^)(]*(?:\\([^)(]*\\)[^)(]*)*\\)[^)(]*)*\\)[^)(]*)*)\\)",
              --   "'([^']*)'",
              -- },
            },
            validate = true,
          },
        },
      }))
    end
  end

  if utils.exists_in_table(servers, "pylsp") then
    handlers["pylsp"] = function()
      lspconfig.pylsp.setup(make_conf({
        settings = {
          pylsp = {
            plugins = {
              pycodestyle = {
                enabled = true,
                maxLineLength = 100,
              },
              pyflakes = { enabled = true },
              pylint = { enabled = false },
              jedi_completion = {
                enabled = true,
                include_params = true,
              },
              rope_completion = { enabled = true },
              autopep8 = { enabled = false }, -- Disable if using black formatter
              yapf = { enabled = false },
              black = { enabled = true },
              mypy = { enabled = true },
              isort = { enabled = true },
            },
          },
        },
      }))
    end
  end

  if utils.exists_in_table(servers, "ts_ls") then
    handlers["ts_ls"] = function()
      lspconfig.ts_ls.setup(make_conf({
        handlers = {
          ["textDocument/definition"] = function(err, result, ctx, ...)
            if #result > 1 then
              result = { result[1] }
            end
            vim.lsp.handlers["textDocument/definition"](err, result, ctx, ...)
          end,
        },
        root_dir = require("lspconfig/util").root_pattern("tsconfig.json"),
        settings = {
          typescript = {
            inlayHints = {
              includeInlayEnumMemberValueHints = true,
              includeInlayFunctionLikeReturnTypeHints = true,
              includeInlayFunctionParameterTypeHints = true,
              includeInlayParameterNameHints = "all",
              includeInlayParameterNameHintsWhenArgumentMatchesName = true, -- false
              includeInlayPropertyDeclarationTypeHints = true,
              includeInlayVariableTypeHints = true,
              includeInlayVariableTypeHintsWhenTypeMatchesName = true, -- false
            },
          },
          javascript = {
            inlayHints = {
              includeInlayEnumMemberValueHints = true,
              includeInlayFunctionLikeReturnTypeHints = true,
              includeInlayFunctionParameterTypeHints = true,
              includeInlayParameterNameHints = "all",
              includeInlayParameterNameHintsWhenArgumentMatchesName = true,
              includeInlayPropertyDeclarationTypeHints = true,
              includeInlayVariableTypeHints = true,
              includeInlayVariableTypeHintsWhenTypeMatchesName = true,
            },
          },
        },
      }))
    end
  end

  if utils.exists_in_table(servers, "jsonls") then
    handlers["jsonls"] = function()
      lspconfig.jsonls.setup(make_conf({
        cmd = { "vscode-json-language-server", "--stdio" },
        filetypes = { "json", "jsonc" },
        settings = {
          json = {
            schemas = {
              {
                fileMatch = { "package.json" },
                url = "https://json.schemastore.org/package.json",
              },
              {
                fileMatch = { "manifest.json", "manifest.webmanifest" },
                url = "https://json.schemastore.org/web-manifest-combined.json",
              },
              {
                fileMatch = { "tsconfig*.json" },
                url = "https://json.schemastore.org/tsconfig.json",
              },
              {
                fileMatch = {
                  ".prettierrc",
                  ".prettierrc.json",
                  "prettier.config.json",
                },
                url = "https://json.schemastore.org/prettierrc.json",
              },
              {
                fileMatch = { ".eslintrc", ".eslintrc.json" },
                url = "https://json.schemastore.org/eslintrc.json",
              },
              {
                fileMatch = { ".babelrc", ".babelrc.json", "babel.config.json" },
                url = "https://json.schemastore.org/babelrc.json",
              },
              {
                fileMatch = { "lerna.json" },
                url = "https://json.schemastore.org/lerna.json",
              },
              {
                fileMatch = { "now.json", "vercel.json" },
                url = "https://json.schemastore.org/now.json",
              },
              {
                fileMatch = {
                  ".stylelintrc",
                  ".stylelintrc.json",
                  "stylelint.config.json",
                },
                url = "https://json.schemastore.org/stylelintrc.json",
              },
            },
          },
        },
      }))
    end
  end

  if utils.exists_in_table(servers, "denols") then
    handlers["denols"] = function()
      lspconfig.denols.setup(make_conf({
        handlers = {
          ["textDocument/definition"] = function(err, result, ctx, ...)
            vim.notify("Using new definition handler")
            if #result > 1 then
              result = { result[1] }
            end
            vim.lsp.handlers["textDocument/definition"](err, result, ctx, ...)
          end,
        },
        root_dir = require("lspconfig/util").root_pattern("deno.json", "deno.jsonc"),
        init_options = { lint = true },
      }))
    end
  end

  if utils.exists_in_table(servers, "lua_ls") then
    handlers["lua_ls"] = function()
      lspconfig.lua_ls.setup(make_conf({
        settings = {
          Lua = {
            runtime = {
              version = "LuaJIT",
            },
            telemetry = { enable = false },
            hint = { enable = true },
            workspace = {
              checkThirdParty = false,
              library = vim.api.nvim_get_runtime_file("", true),
            },
            codeLens = {
              enable = true,
            },
            diagnostics = {
              globals = { "vim" },
            },
            completion = {
              callSnippet = "Replace",
            },
          },
        },
      }))
    end
  end

  if utils.exists_in_table(servers, "intelephense") then
    handlers["intelephense"] = function()
      lspconfig.intelephense.setup(make_conf({
        cmd = { "intelephense", "--stdio" },
        filetypes = { "php" },
        single_file_support = true,
        root_dir = require("lspconfig/util").root_pattern("composer.json", ".git"),
      }))
    end
  end

  if utils.exists_in_table(servers, "vimls") then
    handlers["vimls"] = function()
      lspconfig.vimls.setup(make_conf({
        init_options = { isNeovim = true },
      }))
    end
  end

  if utils.exists_in_table(servers, "diagnosticls") then
    handlers["diagnosticls"] = function()
      lspconfig.diagnosticls.setup(make_conf({
        settings = {
          filetypes = { "sh" },
          init_options = {
            linters = {
              shellcheck = {
                sourceName = "shellcheck",
                command = "shellcheck",
                debounce = 100,
                args = { "--format=gcc", "-" },
                offsetLine = 0,
                offsetColumn = 0,
                formatLines = 1,
                formatPattern = {
                  "^[^:]+:(\\d+):(\\d+):\\s+([^:]+):\\s+(.*)$",
                  { line = 1, column = 2, message = 4, security = 3 },
                },
                securities = { error = "error", warning = "warning", note = "info" },
              },
            },
            filetypes = { sh = "shellcheck" },
          },
        },
      }))
    end
  end

  vim.diagnostic.config({
    signs = {
      text = {
        [vim.diagnostic.severity.ERROR] = "",
        [vim.diagnostic.severity.WARN] = "",
        [vim.diagnostic.severity.INFO] = "",
        [vim.diagnostic.severity.HINT] = "",
      },
      numhl = {
        [vim.diagnostic.severity.WARN] = "WarningMsg",
        [vim.diagnostic.severity.ERROR] = "ErrorMsg",
        [vim.diagnostic.severity.INFO] = "DiagnosticInfo",
        [vim.diagnostic.severity.HINT] = "DiagnosticHint",
      },
    },
    -- Add virtual text configuration
    virtual_text = {
      spacing = 4,
      source = "if_many", -- Show source only if multiple sources
      prefix = "●", -- Could also use a function for dynamic icons
    },
    -- Improve float windows
    float = {
      border = "rounded",
      source = "if_many",
      header = "",
      prefix = "",
    },
    -- Underline diagnostics
    underline = true,
    -- Update diagnostics in insert mode
    update_in_insert = false,
    -- Sort by severity
    severity_sort = true,
  })

  mason_lspconfig.setup_handlers(handlers)
end

return M
