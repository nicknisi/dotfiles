local config = require("nisi").config

return {
  {
    "saghen/blink.cmp",
    optional = true,
    opts = {
      sources = {
        providers = {
          snippets = {
            opts = {
              search_paths = { config.snippets_dir or vim.fn.stdpath("config") .. "/snippets" },
              global_snippets = { "all", "global" },
              extended_filetypes = {
                javascriptreact = { "javascript" },
                typescriptreact = { "typescript" },
                ["typescript.tsx"] = { "typescript" },
              },
            },
          },
        },
      },
    },
  },
}
