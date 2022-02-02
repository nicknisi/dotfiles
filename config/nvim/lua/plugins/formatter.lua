-- on startup, check if there exists a local version of prettier
-- in the project and use that. Otherwise, use the global version.
local prettier_path = "./node_modules/.bin/prettier"
if vim.fn.executable(prettier_path) ~= 1 then
  prettier_path = "prettier"
end

function prettier_config()
  return {
    exe = prettier_path,
    args = {
      "--config-precedence",
      "prefer-file",
      "--stdin-filepath",
      vim.fn.fnameescape(vim.api.nvim_buf_get_name(0))
    },
    stdin = true
  }
end

require("formatter").setup(
  {
    logging = false,
    filetype = {
      javascript = {
        prettier_config
      },
      typescript = {
        prettier_config
      },
      ["typescript.tsx"] = {
        prettier_config
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

vim.api.nvim_exec(
  [[
augroup FormatAutogroup
  autocmd!
  autocmd BufWritePost *.js,*.ts,*.tsx FormatWrite
  autocmd BufWritePost *.lua FormatWrite
augroup END
]],
  true
)
