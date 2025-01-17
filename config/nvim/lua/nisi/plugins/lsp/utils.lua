local M = {}

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

---Trigger the LSP's provided organizeImports helper (for TypeScript)
function M.lsp_organize_imports()
  local params = { command = "_typescript.organizeImports", arguments = { vim.api.nvim_buf_get_name(0) }, title = "" }
  vim.lsp.buf.execute_command(params)
end

---Show LSP diagnostics
function M.lsp_show_diagnostics()
  vim.diagnostic.open_float({ border = border })
end

---setup default capabilities and configuration for an lsp
---@param ... table<any, any> Overrides to apply to the configuration
function M.make_conf(...)
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
  capabilities = require("blink.cmp").get_lsp_capabilities(capabilities)

  return vim.tbl_deep_extend("force", {
    handlers = {
      ["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = border }),
      ["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = border }),
      ["textDocument/publishDiagnostics"] = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
        virtual_text = true,
      }),
    },
    capabilities = capabilities,
  }, ...)
end

return M
