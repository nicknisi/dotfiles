local lspconfig = require("lspconfig")
local mason_lspconfig = require("mason-lspconfig")
local mason_null_ls = require("mason-null-ls")
local theme = require("theme")
local mason = require("mason")
local border = theme.border
local format_group = vim.api.nvim_create_augroup("LspFormatting", { clear = true })
local null_ls = require("null-ls")
local cmp_nvim_lsp = require("cmp_nvim_lsp")

local M = {}

local function format_async(err, _, result, _, bufnr)
  if err ~= nil or result == nil then
    return
  end
  if not vim.api.nvim_buf_get_option(bufnr, "modified") then
    local view = vim.fn.winsaveview()
    vim.lsp.util.apply_text_edits(result, bufnr, "utf-8")
    if view ~= nil then
      vim.fn.winrestview(view)
    end
    if bufnr == vim.api.nvim_get_current_buf() then
      vim.api.nvim_command("noautocmd :update")
    end
  end
end

local function lsp_organize_imports()
  local params = { command = "_typescript.organizeImports", arguments = { vim.api.nvim_buf_get_name(0) }, title = "" }
  vim.lsp.buf.execute_command(params)
end

local function lsp_show_diagnostics()
  vim.diagnostic.open_float({ border = border })
end

-- _G makes this function available to vimscript lua calls
_G.lsp_organize_imports = lsp_organize_imports

local function make_conf(...)
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  capabilities.textDocument.foldingRange = {
    dynamicRegistration = false,
    lineFoldingOnly = true,
  }
  capabilities.textDocument.completion.completionItem.snippetSupport = true
  capabilities.textDocument.completion.completionItem.resolveSupport = {
    properties = { "documentation", "detail", "additionalTextEdits", "documentHighlight" },
  }
  capabilities.textDocument.colorProvider = { dynamicRegistration = false }
  capabilities = cmp_nvim_lsp.default_capabilities(capabilities)

  return vim.tbl_deep_extend("force", {
    handlers = {
      ["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = border }),
      ["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = border }),
      ["textDocument/formatting"] = format_async,
      ["textDocument/publishDiagnostics"] = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
        virtual_text = true,
      }),
    },
    capabilities = capabilities,
  }, ...)
end

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("UserLspConfig", {}),
  callback = function(ev)
    -- TODO: move this to typescript
    vim.cmd([[command! OR lua lsp_organize_imports()]])

    local opts = { noremap = true, silent = true }
    vim.keymap.set("n", "<leader>aa", lsp_show_diagnostics, opts)
    vim.keymap.set("n", "gl", lsp_show_diagnostics, opts)
    vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
    vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
    vim.keymap.set("n", "<leader>aq", vim.diagnostic.setloclist, opts)

    local bufopts = { noremap = true, silent = true, buffer = ev.buf }
    vim.keymap.set("n", "gO", lsp_organize_imports, bufopts)
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, bufopts)
    vim.keymap.set("n", "gD", vim.lsp.buf.declaration, bufopts)
    vim.keymap.set("n", "go", vim.lsp.buf.type_definition, bufopts)
    vim.keymap.set("n", "gr", vim.lsp.buf.rename, bufopts)
    vim.keymap.set("n", "gR", vim.lsp.buf.references, bufopts)
    vim.keymap.set("n", "gy", vim.lsp.buf.type_definition, bufopts)
    vim.keymap.set("n", "K", vim.lsp.buf.hover, bufopts)
    vim.keymap.set("n", "S", vim.lsp.buf.signature_help, bufopts)
    vim.keymap.set("n", "ga", vim.lsp.buf.code_action, bufopts)

    -- FIXME the following keymaps are not working when using a autocmd to set up
    -- vim.keymap.set("x", "gA", vim.lsp.buf.range_code_action, bufopts)
    -- vim.keymap.set("n", "<C-x><C-x>", vim.lsp.buf.signature_help, bufopts)
  end,
})

function M.setup()
  mason.setup({ ui = { border = border } })

  null_ls.setup({
    border = border,
    root_dir = require("lspconfig/util").root_pattern("package.json", ".git"),
    on_attach = function(client, bufnr)
      if client.supports_method("textDocument/formatting") then
        vim.api.nvim_clear_autocmds({ group = format_group, buffer = bufnr })
        vim.api.nvim_create_autocmd("BufWritePre", {
          group = format_group,
          buffer = bufnr,
          callback = function()
            vim.lsp.buf.format({
              ---@diagnostic disable-next-line: redefined-local
              filter = function(client)
                return client.name == "null-ls"
              end,
              bufnr = bufnr,
            })
          end,
        })
      end
    end,
  })

  mason_null_ls.setup({
    automatic_installation = true,
    ensure_installed = { "stylua", "prettier" },
    handlers = {
      function(source_name, methods)
        require("mason-null-ls.automatic_setup")(source_name, methods)
      end,
    },
  })

  mason_lspconfig.setup({
    ensure_installed = { "eslint", "tsserver", "lua_ls", "denols", "vimls", "astro", "tailwindcss" },
    automatic_installation = true,
    ui = { check_outdated_servers_on_open = true },
  })

  mason_lspconfig.setup_handlers({
    function(server_name)
      lspconfig[server_name].setup(make_conf({}))
    end,

    tailwindcss = function()
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
              classRegex = {
                "tw`([^`]*)",
                'tw="([^"]*)',
                'tw={"([^"}]*)',
                "tw\\.\\w+`([^`]*)",
                "tw\\(.*?\\)`([^`]*)",

                "cn`([^`]*)",
                'cn="([^"]*)',
                'cn={"([^"}]*)',
                "cn\\.\\w+`([^`]*)",
                "cn\\(.*?\\)`([^`]*)",

                { "clsx\\(([^)]*)\\)", "(?:'|\"|`)([^']*)(?:'|\"|`)" },
                { "classnames\\(([^)]*)\\)", "'([^']*)'" },
                { "cva\\(([^)]*)\\)", "[\"'`]([^\"'`]*).*?[\"'`]" },
                "cva\\(([^)(]*(?:\\([^)(]*(?:\\([^)(]*(?:\\([^)(]*\\)[^)(]*)*\\)[^)(]*)*\\)[^)(]*)*)\\)",
                "'([^']*)'",
              },
            },
            validate = true,
          },
        },
      }))
    end,

    eslint = function()
      lspconfig.eslint.setup(make_conf({
        filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact", "json", "jsonc" },
      }))
    end,

    tsserver = function()
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
      }))
    end,

    denols = function()
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
    end,

    lua_ls = function()
      lspconfig.lua_ls.setup(make_conf({
        settings = {
          Lua = {
            completion = { callSnippet = "Replace" },
            runtime = {
              -- LuaJIT in the case of Neovim
              version = "LuaJIT",
              path = vim.split(package.path, ";"),
            },
            diagnostics = {
              -- Get the language server to recognize the `vim` global
              globals = { "vim" },
            },
            workspace = {
              library = vim.api.nvim_get_runtime_file("", true),
              checkThirdParty = false,
            },
          },
        },
      }))
    end,

    vimls = function()
      lspconfig.vimls.setup(make_conf({
        init_options = { isNeovim = true },
      }))
    end,

    diagnosticls = function()
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
    end,

    jsonls = function()
      lspconfig.jsonls.setup(make_conf({
        filetypes = { "json", "jsonc" },
      }))
    end,
  })
end

return M
