local lspconfig = require("lspconfig")
local mason_lspconfig = require("mason-lspconfig")
local mason_null_ls = require("mason-null-ls")
local theme = require("theme")
local mason = require("mason")
local colors = theme.colors
local icons = theme.icons
local border = theme.border
local cmp_nvim_lsp = require("cmp_nvim_lsp")
local group = vim.api.nvim_create_augroup("LspConfig", { clear = true })
local format_group = vim.api.nvim_create_augroup("LspFormatting", { clear = true })
local null_ls = require("null-ls")
local util = lspconfig.util

mason.setup({ ui = { border = border } })

mason_null_ls.setup({
  automatic_setup = true,
  ensure_installed = { "stylua", "prettier" },
  handlers = {
    function(source_name, methods)
      require("mason-null-ls.automatic_setup")(source_name, methods)
    end,
  },
})

null_ls.setup({
  border = border,
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

mason_lspconfig.setup({
  ensure_installed = { "eslint", "tsserver", "lua_ls", "denols", "vimls", "astro", "tailwindcss" },
  automatic_installation = true,
  ui = { check_outdated_servers_on_open = true },
})

local format_async = function(err, _, result, _, bufnr)
  if err ~= nil or result == nil then
    return
  end
  if not vim.api.nvim_buf_get_option(bufnr, "modified") then
    local view = vim.fn.winsaveview()
    vim.lsp.util.apply_text_edits(result, bufnr, "utf-8")
    vim.fn.winrestview(view)
    if bufnr == vim.api.nvim_get_current_buf() then
      vim.api.nvim_command("noautocmd :update")
    end
  end
end

vim.lsp.handlers["textDocument/formatting"] = format_async

local lsp_organize_imports = function()
  local params = { command = "_typescript.organizeImports", arguments = { vim.api.nvim_buf_get_name(0) }, title = "" }
  vim.lsp.buf.execute_command(params)
end
-- _G makes this function available to vimscript lua calls
_G.lsp_organize_imports = lsp_organize_imports

-- show diagnostic line with custom border and styling
local lsp_show_diagnostics = function()
  vim.diagnostic.open_float({ border = border })
end

local function denoless_root_pattern(...)
  local args = { ... }
  return function(fname)
    local directory = util.path.dirname(fname)
    if util.root_pattern("deno.json", "deno.jsonc")(directory) ~= nil then
      return nil
    end
    return util.root_pattern(table.unpack(args))(fname)
  end
end

local on_attach = function(client, bufnr)
  vim.cmd([[command! OR lua lsp_organize_imports()]])
  vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = border })
  vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.hover, { border = border })

  local opts = { noremap = true, silent = true }
  vim.keymap.set("n", "<leader>aa", lsp_show_diagnostics, opts)
  vim.keymap.set("n", "gl", lsp_show_diagnostics, opts)
  vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
  vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
  vim.keymap.set("n", "<leader>aq", vim.diagnostic.setloclist, opts)

  local bufopts = { noremap = true, silent = true, buffer = bufnr }
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
  vim.keymap.set("x", "gA", vim.lsp.buf.range_code_action, bufopts)
  vim.keymap.set("n", "<C-x><C-x>", vim.lsp.buf.signature_help, bufopts)

  if client.server_capabilities.document_highlight then
    vim.api.nvim_create_autocmd("CursorHold", {
      pattern = "*",
      callback = function()
        vim.lsp.buf.document_highlight()
      end,
      group = group,
    })
    vim.api.nvim_create_autocmd("CursorMoved", {
      pattern = "*",
      callback = function()
        vim.lsp.buf.clear_references()
      end,
      group = group,
    })
  end

  client.server_capabilities.document_formatting = false

  if client.server_capabilities.document_formatting then
    vim.api.nvim_create_autocmd("BufEnter", {
      pattern = "*",
      callback = function()
        vim.lsp.buf.formatting()
      end,
      group = group,
    })
  end
end

local diagnosticls_settings = {
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
}

local lua_settings = {
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
}

local function make_config(callback)
  callback = callback or function(config)
    return config
  end
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  capabilities.textDocument.completion.completionItem.snippetSupport = true
  capabilities.textDocument.completion.completionItem.resolveSupport = {
    properties = { "documentation", "detail", "additionalTextEdits" },
  }
  capabilities.textDocument.colorProvider = { dynamicRegistration = false }
  capabilities = cmp_nvim_lsp.default_capabilities(capabilities)

  return callback({ capabilities = capabilities, on_attach = on_attach })
end

mason_lspconfig.setup_handlers({
  function(server_name)
    lspconfig[server_name].setup(make_config())
  end,
  ["tailwindcss"] = function()
    lspconfig.tailwindcss.setup(make_config(function(config)
      config.root_dir = lspconfig.util.root_pattern("tailwind.config.js", "tailwind.config.cjs", "tailwind.config.ts")
      return config
    end))
  end,
  ["eslint"] = function()
    lspconfig.eslint.setup(make_config(function(config)
      config.root_dir =
        denoless_root_pattern(".eslintrc.js", ".eslintrc.cjs", ".eslintrc.yaml", ".eslintrc.yml", ".eslintrc.json")
      config.filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" }
      return config
    end))
  end,
  ["tsserver"] = function()
    lspconfig.tsserver.setup(make_config(function(config)
      config.root_dir = denoless_root_pattern("tsconfig.json")
      config.single_file_support = false
      config.handlers = {
        ["textDocument/definition"] = function(err, result, ctx, conf)
          -- if there is more than one result, just use the first one
          if #result > 1 then
            result = { result[1] }
          end
          vim.lsp.handlers["textDocument/definition"](err, result, ctx, conf)
        end,
      }
      return config
    end))
  end,
  ["denols"] = function()
    lspconfig.denols.setup(make_config(function(config)
      config.single_file_support = false
      config.root_dir = lspconfig.util.root_pattern("deno.json", "deno.jsonc")
      config.init_options = { lint = true }
      return config
    end))
  end,
  ["lua_ls"] = function()
    lspconfig.lua_ls.setup(make_config(function(config)
      config.settings = lua_settings
      config.root_dir = function(fname)
        local util = require("lspconfig/util")
        return util.find_git_ancestor(fname) or util.path.dirname(fname)
      end
      config.root_dir = lspconfig.util.root_pattern("lua.json")
      return config
    end))
  end,
  ["vimls"] = function()
    lspconfig.vimls.setup(make_config(function(config)
      config.init_options = { isNeovim = true }
      return config
    end))
  end,
  ["diagnosticls"] = function()
    lspconfig.diagnosticls.setup(make_config(function(config)
      config.settings = diagnosticls_settings
      return config
    end))
  end,
  ["jsonls"] = function()
    lspconfig.jsonls.setup(make_config(function(config)
      config.filetypes = { "json", "jsonc" }
      return config
    end))
  end,
})

-- set up custom symbols for LSP errors
local signs =
  { Error = icons.error, Warning = icons.warning, Warn = icons.warning, Hint = icons.hint, Info = icons.hint }
for type, icon in pairs(signs) do
  local hl = "DiagnosticSign" .. type
  vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
end

vim.diagnostic.config({ virtual_text = true, signs = true, update_in_insert = true, severity_sort = true })

-- Set colors for completion items
vim.cmd("highlight! CmpItemAbbrMatch guibg=NONE guifg=" .. colors.lightblue)
vim.cmd("highlight! CmpItemAbbrMatchFuzzy guibg=NONE guifg=" .. colors.lightblue)
vim.cmd("highlight! CmpItemKindFunction guibg=NONE guifg=" .. colors.magenta)
vim.cmd("highlight! CmpItemKindMethod guibg=NONE guifg=" .. colors.magenta)
vim.cmd("highlight! CmpItemKindVariable guibg=NONE guifg=" .. colors.blue)
vim.cmd("highlight! CmpItemKindKeyword guibg=NONE guifg=" .. colors.fg)
