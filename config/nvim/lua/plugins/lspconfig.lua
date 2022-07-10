local utils = require("utils")
local nmap = utils.nmap
local imap = utils.imap
local cmd = vim.cmd
local api = vim.api
local fn = vim.fn
local lsp = vim.lsp
local lsp_installer = require("nvim-lsp-installer")
local nvim_lsp = require("lspconfig")
local theme = require("theme")
local colors = theme.colors
local icons = theme.icons

cmd("autocmd ColorScheme * highlight NormalFloat guibg=" .. colors.bg)
cmd("autocmd ColorScheme * highlight FloatBorder guifg=white guibg=" .. colors.bg)

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
  if not api.nvim_buf_get_option(bufnr, "modified") then
    local view = fn.winsaveview()
    lsp.util.apply_text_edits(result, bufnr)
    fn.winrestview(view)
    if bufnr == api.nvim_get_current_buf() then
      api.nvim_command("noautocmd :update")
    end
  end
end

lsp.handlers["textDocument/formatting"] = format_async

local lsp_organize_imports = function()
  local params = {
    command = "_typescript.organizeImports",
    arguments = {api.nvim_buf_get_name(0)},
    title = ""
  }
  lsp.buf.execute_command(params)
end
-- _G makes this function available to vimscript lua calls
_G.lsp_organize_imports = lsp_organize_imports

-- show diagnostic line with custom border and styling
local lsp_show_diagnostics = function()
  vim.diagnostic.open_float({border = border})
end

local on_attach = function(client, bufnr)
  cmd [[command! OR lua lsp_organize_imports()]]
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

  if client.server_capabilities.document_highlight then
    api.nvim_exec(
      [[
    augroup lsp_document_highlight
      autocmd! * <buffer>
      autocmd CursorHold <buffer> lua vim.lsp.buf.document_highlight()
      autocmd CursorMoved <buffer> lua vim.lsp.buf.clear_references()
    augroup END
    ]],
      false
    )
  end

  -- disable document formatting (currently handled by formatter.nvim)
  client.server_capabilities.document_formatting = false

  if client.server_capabilities.document_formatting then
    api.nvim_exec(
      [[
        augroup LspAutocommands
        autocmd! * <buffer>
        autocmd BufWritePost <buffer> LspFormatting
        augroup END
      ]],
      true
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
        [fn.expand("$VIMRUNTIME/lua")] = true,
        [fn.expand("$VIMRUNTIME/lua/vim/lsp")] = true
      }
    }
  }
}

local function make_config()
  local capabilities = lsp.protocol.make_client_capabilities()
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
      opts.root_dir = nvim_lsp.util.root_pattern("package.json")
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
      opts.root_dir = nvim_lsp.util.root_pattern("deno.json")
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
cmd("highlight! CmpItemAbbrMatch guibg=NONE guifg=" .. colors.lightblue)
cmd("highlight! CmpItemAbbrMatchFuzzy guibg=NONE guifg=" .. colors.lightblue)
cmd("highlight! CmpItemKindFunction guibg=NONE guifg=" .. colors.magenta)
cmd("highlight! CmpItemKindMethod guibg=NONE guifg=" .. colors.magenta)
cmd("highlight! CmpItemKindVariable guibg=NONE guifg=" .. colors.blue)
cmd("highlight! CmpItemKindKeyword guibg=NONE guifg=" .. colors.fg)
