local M = {}

local border = "rounded"

---Trigger the LSP's provided organizeImports helper (for TypeScript)
function M.lsp_organize_imports()
  vim.lsp.buf.code_action({
    context = {
      only = { "source.organizeImports" },
      diagnostics = {},
    },
    apply = true,
  })
end

---Show LSP diagnostics
function M.lsp_show_diagnostics()
  vim.diagnostic.open_float({ border = border })
end

---setup default capabilities and configuration for an lsp
---@param ... table<any, any> Overrides to apply to the configuration
function M.make_conf(...)
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  capabilities = require("blink.cmp").get_lsp_capabilities(capabilities)

  return vim.tbl_deep_extend("force", {
    capabilities = capabilities,
  }, ...)
end

return M
