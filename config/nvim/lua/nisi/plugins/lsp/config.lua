local lsp_utils = require("nisi.plugins.lsp.utils")
local make_conf = lsp_utils.make_conf
local lspconfig = require("lspconfig")
local mason = require("mason")
local mason_lspconfig = require("mason-lspconfig")
local utils = require("nisi.utils")
local fn = utils.fn
local border = {
  { "🭽", "FloatBorder" },
  { "▔", "FloatBorder" },
  { "🭾", "FloatBorder" },
  { "▕", "FloatBorder" },
  { "🭿", "FloatBorder" },
  { "▁", "FloatBorder" },
  { "🭼", "FloatBorder" },
  { "▏", "FloatBorder" },
}

local servers = {
  "eslint",
  "ts_ls",
  "lua_ls",
  "denols",
  "astro",
  "gopls",
  "intelephense",
  "tailwindcss",
  "jsonls",
  "pylsp",
  "ruby_lsp",
  "pylsp",
  "vimls",
}

local M = {}

-- _G makes this function available to vimscript lua calls
_G.lsp_organize_imports = lsp_utils.lsp_organize_imports

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("UserLspConfig", {}),
  callback = function(ev)
    -- TODO: move this to typescript
    vim.cmd([[command! OR lua lsp_organize_imports()]])

    local function keymap(key, action, buf, desc)
      local opts = { noremap = true, silent = true, desc = desc }
      if buf then
        opts.buffer = ev.buf
      end
      vim.keymap.set("n", key, action, opts)
    end

    keymap("<leader>aa", lsp_utils.lsp_show_diagnostics, false, "Show diagnostics")
    keymap("[d", fn(vim.diagnostic.jump, { count = -1 }), false, "Go to previous diagnostic")
    keymap("]d", fn(vim.diagnostic.jump, { count = 1 }), false, "Go to next diagnostic")
    keymap("<leader>aq", vim.diagnostic.setloclist, false, "Send diagnostics to loclist")

    keymap("gO", lsp_utils.lsp_organize_imports, true, "Organize imports")
    keymap("gd", vim.lsp.buf.definition, true, "Go to definition")
    keymap("gD", vim.lsp.buf.declaration, true, "Go to declaration")
    keymap("go", vim.lsp.buf.type_definition, true, "Go to type definition")
    keymap("gr", vim.lsp.buf.rename, true, "Rename")
    keymap("gR", vim.lsp.buf.references, true, "Show references")
    keymap("gy", vim.lsp.buf.type_definition, true, "")
    keymap("K", vim.lsp.buf.hover, true, "Show hover")
    keymap("S", vim.lsp.buf.signature_help, true, "Show signature")
    keymap("ga", vim.lsp.buf.code_action, true, "Show LSP code actions")

    if vim.lsp.inlay_hint then
      keymap("<Leader>hh", function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
      end, false, "Toggle inlay [h]ints")
    end

    -- FIXME the following keymaps are not working when using a autocmd to set up
    -- vim.keymap.set("x", "gA", vim.lsp.buf.range_code_action, bufopts)
    -- vim.keymap.set("n", "<C-x><C-x>", vim.lsp.buf.signature_help, bufopts)

    -- set up mousemenu options for lsp
    vim.cmd([[:amenu 10.100 mousemenu.Goto\ Definition <cmd>Telescope lsp_definitions<cr>]])
    vim.cmd([[:amenu 10.110 mousemenu.References <cmd>Telescope lsp_references<cr>]])
    vim.cmd([[:amenu 10.120 mousemenu.Implementation <cmd>Telescope lsp_implementations<cr>]])

    vim.keymap.set("n", "<RightMouse>", "<cmd>:popup mousemenu<cr>")
  end,
})

function M.setup()
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
                url = "http://json.schemastore.org/stylelintrc.json",
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
  })

  mason_lspconfig.setup_handlers(handlers)
end

return M
