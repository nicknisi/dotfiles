local utils = require("utils")
local nmap = utils.nmap
local imap = utils.imap
local lsp_installer = require("nvim-lsp-installer")
local lspconfig = require("lspconfig")
local theme = require("theme")
local colors = theme.colors
local icons = theme.icons

vim.cmd("autocmd ColorScheme * highlight NormalFloat guibg=" .. colors.bg)
vim.cmd("autocmd ColorScheme * highlight FloatBorder guifg=white guibg=" .. colors.bg)

local border = {
  {"🭽", "FloatBorder"},
  {"▔", "FloatBorder"},
  {"🭾", "FloatBorder"},
  {"▕", "FloatBorder"},
  {"🭿", "FloatBorder"},
  {"▁", "FloatBorder"},
  {"🭼", "FloatBorder"},
  {"▏", "FloatBorder"}
}

local format_async = function(err, _, result, _, bufnr)
  if err ~= nil or result == nil then
    return
  end
  if not vim.api.nvim_buf_get_option(bufnr, "modified") then
    local view = vim.fn.winsaveview()
    vim.lsp.util.apply_text_edits(result, bufnr)
    vim.fn.winrestview(view)
    if bufnr == vim.api.nvim_get_current_buf() then
      vim.api.nvim_command("noautocmd :update")
    end
  end
end

vim.lsp.handlers["textDocument/formatting"] = format_async

local lsp_organize_imports = function()
  local params = {
    command = "_typescript.organizeImports",
    arguments = {vim.api.nvim_buf_get_name(0)},
    title = ""
  }
  vim.lsp.buf.execute_command(params)
end
-- _G makes this function available to vimscript lua calls
_G.lsp_organize_imports = lsp_organize_imports

-- show diagnostic line with custom border and styling
local lsp_show_diagnostics = function()
  vim.diagnostic.open_float({border = border})
end

local on_attach = function(client, bufnr)
  vim.cmd [[command! OR lua lsp_organize_imports()]]
  vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {border = border})
  vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.hover, {border = border})

  local opts = {noremap = true, silent = true}
  vim.keymap.set("n", "<leader>aa", lsp_show_diagnostics, opts)
  vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
  vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
  vim.keymap.set("n", "<leader>aq", vim.diagnostic.setloclist, opts)

  local bufopts = {noremap = true, silent = true, buffer = bufnr}
  vim.keymap.set("n", "gO", lsp_organize_imports, bufopts)
  vim.keymap.set("n", "gd", vim.lsp.buf.definition, bufopts)
  vim.keymap.set("n", "gr", vim.lsp.buf.rename, bufopts)
  vim.keymap.set("n", "gR", vim.lsp.buf.references, bufopts)
  vim.keymap.set("n", "gy", vim.lsp.buf.type_definition, bufopts)
  vim.keymap.set("n", "K", vim.lsp.buf.hover, bufopts)
  vim.keymap.set("n", "ga", vim.lsp.buf.code_action, bufopts)
  vim.keymap.set("n", "<C-x><C-x>", vim.lsp.buf.signature_help, bufopts)

  local group = vim.api.nvim_create_augroup("LspConfig", {clear = false})

  if client.server_capabilities.document_highlight then
    vim.api.nvim_create_autocmd(
      "CursorHold",
      {
        pattern = "*",
        callback = function()
          vim.lsp.buf.document_highlight()
        end,
        group = group
      }
    )
    vim.api.nvim_create_autocmd(
      "CursorMoved",
      {
        pattern = "*",
        callback = function()
          vim.lsp.buf.clear_references()
        end,
        group = group
      }
    )
  end

  -- disable document formatting (currently handled by formatter.nvim)
  client.server_capabilities.document_formatting = false

  if client.server_capabilities.document_formatting then
    vim.api.nvim_create_autocmd(
      "BufEnter",
      {
        pattern = "*",
        callback = function()
          vim.lsp.buf.formatting()
        end,
        group = group
      }
    )
  end
end

local diagnosticls_settings = {
  filetypes = {
    "sh"
  },
  init_options = {
    linters = {
      shellcheck = {
        sourceName = "shellcheck",
        command = "shellcheck",
        debounce = 100,
        args = {"--format=gcc", "-"},
        offsetLine = 0,
        offsetColumn = 0,
        formatLines = 1,
        formatPattern = {
          "^[^:]+:(\\d+):(\\d+):\\s+([^:]+):\\s+(.*)$",
          {line = 1, column = 2, message = 4, security = 3}
        },
        securities = {error = "error", warning = "warning", note = "info"}
      }
    },
    filetypes = {
      sh = "shellcheck"
    }
  }
}

local lua_settings = {
  Lua = {
    runtime = {
      -- LuaJIT in the case of Neovim
      version = "LuaJIT",
      path = vim.split(package.path, ";")
    },
    diagnostics = {
      -- Get the language server to recognize the `vim` global
      globals = {"vim"}
    },
    workspace = {
      -- Make the server aware of Neovim runtime files
      library = {
        [vim.fn.expand("$VIMRUNTIME/lua")] = true,
        [vim.fn.expand("$VIMRUNTIME/lua/vim/lsp")] = true
      }
    }
  }
}

local function make_config()
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  capabilities.textDocument.completion.completionItem.snippetSupport = true
  capabilities.textDocument.completion.completionItem.resolveSupport = {
    properties = {
      "documentation",
      "detail",
      "additionalTextEdits"
    }
  }
  capabilities.textDocument.colorProvider = {dynamicRegistration = false}

  return {
    capabilities = capabilities,
    on_attach = on_attach
  }
end

lsp_installer.on_server_ready(
  function(server)
    local opts = make_config()
    if server.name == "lua" then
      opts.settings = lua_settings
      opts.root_dir = function(fname)
        local util = require("lspconfig/util")
        return util.find_git_ancestor(fname) or util.path.dirname(fname)
      end
    elseif server.name == "vim" then
      opts.init_options = {isNeovim = true}
    elseif server.name == "diagnosticls" then
      opts = diagnosticls_settings
    elseif server.name == "tsserver" then
      local capabilities = opts.capabilities
      opts.capabiltiies = require("cmp_nvim_lsp").update_capabilities(capabilities)
      opts.root_dir = lspconfig.util.root_pattern("package.json")
      opts.handlers = {
        ["textDocument/definition"] = function(err, result, ctx, config)
          -- if there is more than one result, just use the first one
          if #result > 1 then
            result = {result[1]}
          end
          vim.lsp.handlers["textDocument/definition"](err, result, ctx, config)
        end
      }
    elseif server.name == "denols" then
      opts.root_dir = lspconfig.util.root_pattern("deno.json")
      opts.init_options = {
        lint = true
      }
    end

    server:setup(opts)
  end
)

-- set up custom symbols for LSP errors
local signs = {Error = icons.error, Warning = icons.warning, Warn = icons.warning, Hint = icons.hint, Info = icons.hint}
for type, icon in pairs(signs) do
  local hl = "DiagnosticSign" .. type
  vim.fn.sign_define(hl, {text = icon, texthl = hl, numhl = hl})
end

-- Set colors for completion items
vim.cmd("highlight! CmpItemAbbrMatch guibg=NONE guifg=" .. colors.lightblue)
vim.cmd("highlight! CmpItemAbbrMatchFuzzy guibg=NONE guifg=" .. colors.lightblue)
vim.cmd("highlight! CmpItemKindFunction guibg=NONE guifg=" .. colors.magenta)
vim.cmd("highlight! CmpItemKindMethod guibg=NONE guifg=" .. colors.magenta)
vim.cmd("highlight! CmpItemKindVariable guibg=NONE guifg=" .. colors.blue)
vim.cmd("highlight! CmpItemKindKeyword guibg=NONE guifg=" .. colors.fg)
