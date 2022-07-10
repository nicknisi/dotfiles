local utils = require("utils")
local formatter = require("formatter")
-- on startup, check if there exists a local version of prettier
-- in the project and use that. Otherwise, use the global version.
local prettier_path = "./node_modules/.bin/prettier"
if vim.fn.executable(prettier_path) ~= 1 then
  prettier_path = "prettier"
end

local function is_deno_project()
  return utils.has_active_lsp_client("denols")
end

local function prettier_config()
  if (not is_deno_project()) then
    return {
      exe = prettier_path,
      args = {
        "--config-precedence",
        "prefer-file",
        "--stdin-filepath",
        vim.fn.fnameescape(vim.api.nvim_buf_get_name(0))
      },
      stdin = true,
      try_node_modules = true
    }
  end
  return {}
end

local function deno_config()
  if (is_deno_project()) then
    return {
      exe = "deno",
      args = {
        "fmt",
        "-"
      },
      stdin = true,
      try_node_modules = true
    }
  end
  return {}
end

formatter.setup(
  {
    logging = false,
    filetype = {
      javascript = {
        prettier_config
      },
      typescript = {
        prettier_config,
        deno_config
      },
      ["typescript.tsx"] = {
        prettier_config,
        deno_config
      },
      lua = {
        -- luafmt
        function()
          return {
            exe = "luafmt",
            args = {"--indent-count", 2, "--stdin"},
            stdin = true
          }
        end
      }
    }
  }
)

local group = vim.api.nvim_create_augroup("LspConfig", {clear = true})
vim.api.nvim_create_autocmd(
  "BufWritePost",
  {
    pattern = {"*.lua", "*.ts", "*.tsx", "*.js", "*.jsx", "*.json"},
    command = "FormatWrite",
    group = group
  }
)
