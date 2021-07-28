local utils = require("utils")
local nmap = utils.nmap
local imap = utils.imap
local cmd = vim.cmd
local api = vim.api
local fn = vim.fn
local lsp = vim.lsp

-- lspconfig config

local nvim_lsp = require("lspconfig")
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

-- _G makes this function available to vimscript lua calls
_G.lsp_organize_imports = function()
  local params = {
    command = "_typescript.organizeImports",
    arguments = {api.nvim_buf_get_name(0)},
    title = ""
  }
  lsp.buf.execute_command(params)
end
local on_attach = function(client, bufnr)
  local buf_map = api.nvim_buf_set_keymap
  cmd("command! LspDef lua vim.lsp.buf.definition()")
  cmd("command! LspFormatting lua vim.lsp.buf.formatting()")
  cmd("command! LspCodeAction lua vim.lsp.buf.code_action()")
  cmd("command! LspHover lua vim.lsp.buf.hover()")
  cmd("command! LspRename lua vim.lsp.buf.rename()")
  cmd("command! LspOrganize lua lsp_organize_imports()")
  cmd("command! LspRefs lua vim.lsp.buf.references()")
  cmd("command! LspTypeDef lua vim.lsp.buf.type_definition()")
  cmd("command! LspImplementation lua vim.lsp.buf.implementation()")
  cmd("command! LspDiagPrev lua vim.lsp.diagnostic.goto_prev()")
  cmd("command! LspDiagNext lua vim.lsp.diagnostic.goto_next()")
  cmd("command! LspDiagLine lua vim.lsp.diagnostic.show_line_diagnostics()")
  cmd("command! LspSignatureHelp lua vim.lsp.buf.signature_help()")

  nmap("gd", ":LspDef<CR>", {bufnr = bufnr})
  nmap("gr", ":LspRename<CR>", {bufnr = bufnr})
  nmap("gR", ":LspRefs<CR>", {bufnr = bufnr})
  nmap("gy", ":LspTypeDef<CR>", {bufnr = bufnr})
  nmap("K", ":LspHover<CR>", {bufnr = bufnr})
  nmap("gs", ":LspOrganize<CR>", {bufnr = bufnr})
  nmap("[a", ":LspDiagPrev<CR>", {bufnr = bufnr})
  nmap("]a", ":LspDiagNext<CR>", {bufnr = bufnr})
  nmap("ga", ":LspCodeAction<CR>", {bufnr = bufnr})
  nmap("<Leader>a", ":LspDiagLine<CR>", {bufnr = bufnr})
  imap("<C-x><C-x>", "<cmd> LspSignatureHelp<CR>", {bufnr = bufnr})

  if client.resolved_capabilities.document_formatting then
    vim.api.nvim_exec(
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

nvim_lsp.tsserver.setup {
  on_attach = function(client)
    client.resolved_capabilities.document_formatting = false
    on_attach(client)
  end
}

local filetypes = {
  typescript = "eslint",
  typescriptreact = "eslint"
}
local linters = {
  eslint = {
    sourceName = "eslint",
    command = "eslint_d",
    rootPatterns = {".eslintrc.js", "package.json"},
    debounce = 100,
    args = {"--stdin", "--stdin-filename", "%filepath", "--format", "json"},
    parseJson = {
      errorsRoot = "[0].messages",
      line = "line",
      column = "column",
      endLine = "endLine",
      endColumn = "endColumn",
      message = "${message} [${ruleId}]",
      security = "severity"
    },
    securities = {[2] = "error", [1] = "warning"}
  }
}
local formatters = {
  prettier = {command = "prettier", args = {"--stdin-filepath", "%filepath"}}
}
local formatFiletypes = {
  typescript = "prettier",
  typescriptreact = "prettier"
}
nvim_lsp.diagnosticls.setup {
  on_attach = on_attach,
  filetypes = vim.tbl_keys(filetypes),
  init_options = {
    filetypes = filetypes,
    linters = linters,
    formatters = formatters,
    formatFiletypes = formatFiletypes
  }
}

-- set up custom symbols for LSP errors
fn.sign_define("LspDiagnosticsSignError", {text = "✖", texthl = "LspDiagnosticsSignError", linehl = "", numhl = ""})
fn.sign_define("LspDiagnosticsSignWarning", {text = "⚠", texthl = "LspDiagnosticsSignWarning"})
fn.sign_define("LspDiagnosticsSignInformation", {text = "●", texthl = "LspDiagnosticsSignInfo"})
fn.sign_define("LspDiagnosticsSignHint", {text = "○", texthl = "LspDiagnosticsSignHint"})
