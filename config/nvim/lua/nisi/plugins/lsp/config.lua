local lsp_utils = require("nisi.plugins.lsp.utils")
local make_conf = lsp_utils.make_conf
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
    virtual_text = {
      spacing = 4,
      source = "if_many",
      prefix = "●",
    },
    float = {
      border = "rounded",
      source = "if_many",
      header = "",
      prefix = "",
    },
    underline = true,
    update_in_insert = false,
    severity_sort = true,
  })

  -- Configure LSP servers using vim.lsp.config() before mason-lspconfig.setup()
  if utils.exists_in_table(servers, "eslint") then
    vim.lsp.config(
      "eslint",
      make_conf({
        root_markers = {
          "eslint.config.js",
          "eslint.config.mjs",
          ".eslintrc.js",
          ".eslintrc.json",
          ".eslintrc",
        },
      })
    )
  end

  if utils.exists_in_table(servers, "tailwindcss") then
    vim.lsp.config(
      "tailwindcss",
      make_conf({
        root_markers = {
          "tailwind.config.js",
          "tailwind.config.ts",
          "tailwind.config.cjs",
        },
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
            experimental = {},
            validate = true,
          },
        },
      })
    )
  end

  if utils.exists_in_table(servers, "pylsp") then
    vim.lsp.config(
      "pylsp",
      make_conf({
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
              autopep8 = { enabled = false },
              yapf = { enabled = false },
              black = { enabled = true },
              mypy = { enabled = true },
              isort = { enabled = true },
            },
          },
        },
      })
    )
  end

  if utils.exists_in_table(servers, "ts_ls") then
    vim.lsp.config(
      "ts_ls",
      make_conf({
        handlers = {
          ["textDocument/definition"] = function(err, result, ctx, ...)
            if result and #result > 1 then
              result = { result[1] }
            end
            vim.lsp.handlers["textDocument/definition"](err, result, ctx, ...)
          end,
        },
        root_markers = { "tsconfig.json" },
        settings = {
          typescript = {
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
      })
    )
  end

  if utils.exists_in_table(servers, "jsonls") then
    vim.lsp.config(
      "jsonls",
      make_conf({
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
      })
    )
  end

  if utils.exists_in_table(servers, "denols") then
    vim.lsp.config(
      "denols",
      make_conf({
        handlers = {
          ["textDocument/definition"] = function(err, result, ctx, ...)
            if result and #result > 1 then
              result = { result[1] }
            end
            vim.lsp.handlers["textDocument/definition"](err, result, ctx, ...)
          end,
        },
        root_markers = { "deno.json", "deno.jsonc" },
        init_options = { lint = true },
      })
    )
  end

  if utils.exists_in_table(servers, "lua_ls") then
    vim.lsp.config(
      "lua_ls",
      make_conf({
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
      })
    )
  end

  if utils.exists_in_table(servers, "intelephense") then
    vim.lsp.config(
      "intelephense",
      make_conf({
        cmd = { "intelephense", "--stdio" },
        filetypes = { "php" },
        workspace_required = false,
        root_markers = { "composer.json", ".git" },
      })
    )
  end

  if utils.exists_in_table(servers, "vimls") then
    vim.lsp.config(
      "vimls",
      make_conf({
        init_options = { isNeovim = true },
      })
    )
  end

  -- Setup mason-lspconfig with automatic_enable
  -- Exclude conflicting TypeScript servers from automatic enable
  mason_lspconfig.setup({
    ensure_installed = servers,
    automatic_enable = {
      exclude = { "denols", "ts_ls" },
    },
  })

  -- Manually enable TypeScript server based on project type
  -- This is necessary because both denols and ts_ls handle the same filetypes,
  -- so we need explicit detection to prevent conflicts
  vim.api.nvim_create_autocmd("FileType", {
    pattern = { "typescript", "javascript", "typescriptreact", "javascriptreact" },
    callback = function()
      -- Deno projects take precedence
      if vim.fs.root(0, { "deno.json", "deno.jsonc" }) then
        vim.lsp.enable("denols")
      elseif vim.fs.root(0, { "tsconfig.json", "jsconfig.json", "package.json" }) then
        vim.lsp.enable("ts_ls")
      end
    end,
  })
end

return M
