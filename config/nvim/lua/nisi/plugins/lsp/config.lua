local lsp_utils = require("nisi.plugins.lsp.utils")
local make_conf = lsp_utils.make_conf
local lspconfig = require("lspconfig")
local mason = require("mason")
local mason_lspconfig = require("mason-lspconfig")
local utils = require("nisi.utils")
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
  "tsserver",
  "lua_ls",
  "denols",
  "astro",
  "tailwindcss",
  "jsonls",
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

    local opts = { noremap = true, silent = true }
    vim.keymap.set("n", "<leader>aa", lsp_utils.lsp_show_diagnostics, opts)
    vim.keymap.set("n", "gl", lsp_utils.lsp_show_diagnostics, opts)
    vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
    vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
    vim.keymap.set("n", "<leader>aq", vim.diagnostic.setloclist, opts)

    local bufopts = { noremap = true, silent = true, buffer = ev.buf }
    vim.keymap.set("n", "gO", lsp_utils.lsp_organize_imports, bufopts)
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, bufopts)
    vim.keymap.set("n", "gD", vim.lsp.buf.declaration, bufopts)
    vim.keymap.set("n", "go", vim.lsp.buf.type_definition, bufopts)
    vim.keymap.set("n", "gr", vim.lsp.buf.rename, bufopts)
    vim.keymap.set("n", "gR", vim.lsp.buf.references, bufopts)
    vim.keymap.set("n", "gy", vim.lsp.buf.type_definition, bufopts)
    vim.keymap.set("n", "K", vim.lsp.buf.hover, bufopts)
    vim.keymap.set("n", "S", vim.lsp.buf.signature_help, bufopts)
    vim.keymap.set("n", "ga", vim.lsp.buf.code_action, bufopts)

    if vim.lsp.inlay_hint then
      vim.keymap.set("n", "<Leader>hh", function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
      end, { desc = "toggle inlay [h]ints" })
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

  if utils.exists_in_table(servers, "eslint") then
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

  if utils.exists_in_table(servers, "tsserver") then
    handlers["tsserver"] = function()
      lspconfig.tsserver.setup(make_conf({
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
            telemetry = { enable = false },
            hint = { enable = true },
            workspace = {
              checkThirdParty = false,
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

  mason_lspconfig.setup_handlers(handlers)
end

return M
