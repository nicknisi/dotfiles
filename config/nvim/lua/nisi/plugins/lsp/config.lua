local servers = {
  "eslint",
  "elixirls",
  "ts_ls",
  "lua_ls",
  "denols",
  "astro",
  "gopls",
  "intelephense",
  "tailwindcss",
  "jsonls",
  "ruby_lsp",
  "pylsp",
  "vimls",
}

---Remove unused imports, then organize the rest (TypeScript)
local function organize_imports()
  vim.lsp.buf.code_action({
    context = { only = { "source.removeUnusedImports" }, diagnostics = {} },
    apply = true,
  })
  -- Defer second action to allow first edit to complete
  vim.defer_fn(function()
    vim.lsp.buf.code_action({
      context = { only = { "source.organizeImports" }, diagnostics = {} },
      apply = true,
    })
  end, 100)
end

---Jump straight to the first definition instead of opening a list
local function first_definition(err, result, ctx, ...)
  if result and #result > 1 then
    result = { result[1] }
  end
  vim.lsp.handlers["textDocument/definition"](err, result, ctx, ...)
end

local M = {}

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("UserLspConfig", {}),
  callback = function(ev)
    vim.api.nvim_buf_create_user_command(ev.buf, "OR", organize_imports, {})

    local function map(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = ev.buf, desc = desc, silent = true })
    end

    map("n", "gO", organize_imports, "Organize imports")
    map("n", "gd", vim.lsp.buf.definition, "Go to definition")
    map("n", "gD", vim.lsp.buf.declaration, "Go to declaration")
    map("n", "go", vim.lsp.buf.type_definition, "Go to type definition")
    map("n", "gr", vim.lsp.buf.rename, "Rename")
    map("n", "gR", vim.lsp.buf.references, "Show references")
    map("n", "S", vim.lsp.buf.signature_help, "Show signature")
    map("n", "ga", vim.lsp.buf.code_action, "Show LSP code actions")
    map("v", "ga", vim.lsp.buf.code_action, "Show LSP code actions")
    map("n", "<RightMouse>", "<cmd>:popup mousemenu<cr>", "Show context menu")

    -- set up mousemenu options for lsp
    vim.cmd([[:amenu 10.100 mousemenu.Goto\ Definition <cmd>Telescope lsp_definitions<cr>]])
    vim.cmd([[:amenu 10.110 mousemenu.References <cmd>Telescope lsp_references<cr>]])
    vim.cmd([[:amenu 10.120 mousemenu.Implementation <cmd>Telescope lsp_implementations<cr>]])
  end,
})

function M.setup()
  vim.keymap.set("n", "<leader>aa", vim.diagnostic.open_float, { desc = "Show diagnostics" })
  vim.keymap.set("n", "<leader>aq", vim.diagnostic.setloclist, { desc = "Send diagnostics to loclist" })

  -- Configure LSP servers using vim.lsp.config() before mason-lspconfig.setup()
  vim.lsp.config("eslint", {
    root_markers = {
      "eslint.config.js",
      "eslint.config.mjs",
      ".eslintrc.js",
      ".eslintrc.json",
      ".eslintrc",
    },
  })

  vim.lsp.config("tailwindcss", {
    root_markers = {
      "tailwind.config.js",
      "tailwind.config.ts",
      "tailwind.config.cjs",
    },
    init_options = {
      userLanguages = {
        elixir = "html-eex",
        eelixir = "html-eex",
        heex = "html-eex",
      },
    },
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
        experimental = {},
        validate = true,
      },
    },
  })

  vim.lsp.config("astro", {
    before_init = function(_, conf)
      local tsdk = require("lspconfig.util").get_typescript_server_path(conf.root_dir)
      if tsdk == "" then
        tsdk = require("mason-registry").get_package("typescript-language-server"):get_install_path()
          .. "/node_modules/typescript/lib"
      end
      conf.init_options.typescript.tsdk = tsdk
    end,
  })

  vim.lsp.config("pylsp", {
    settings = {
      pylsp = {
        plugins = {
          pycodestyle = {
            enabled = true,
            maxLineLength = 100,
          },
          pyflakes = { enabled = true },
          pylint = { enabled = false },
          jedi_completion = {
            enabled = true,
            include_params = true,
          },
          rope_completion = { enabled = true },
          autopep8 = { enabled = false },
          yapf = { enabled = false },
          black = { enabled = true },
          mypy = { enabled = true },
          isort = { enabled = true },
        },
      },
    },
  })

  vim.lsp.enable("oxlint")
  vim.lsp.config("ts_ls", {
    handlers = { ["textDocument/definition"] = first_definition },
    root_markers = { "tsconfig.json" },
    settings = {
      typescript = {
        inlayHints = {
          includeInlayEnumMemberValueHints = true,
          includeInlayFunctionLikeReturnTypeHints = true,
          includeInlayFunctionParameterTypeHints = true,
          includeInlayParameterNameHints = "all",
          includeInlayParameterNameHintsWhenArgumentMatchesName = true,
          includeInlayPropertyDeclarationTypeHints = true,
          includeInlayVariableTypeHints = true,
          includeInlayVariableTypeHintsWhenTypeMatchesName = true,
        },
      },
      javascript = {
        inlayHints = {
          includeInlayEnumMemberValueHints = true,
          includeInlayFunctionLikeReturnTypeHints = true,
          includeInlayFunctionParameterTypeHints = true,
          includeInlayParameterNameHints = "all",
          includeInlayParameterNameHintsWhenArgumentMatchesName = true,
          includeInlayPropertyDeclarationTypeHints = true,
          includeInlayVariableTypeHints = true,
          includeInlayVariableTypeHintsWhenTypeMatchesName = true,
        },
      },
    },
  })

  vim.lsp.config("jsonls", {
    settings = {
      json = {
        schemas = {
          {
            fileMatch = { "package.json" },
            url = "https://json.schemastore.org/package.json",
          },
          {
            fileMatch = { "manifest.json", "manifest.webmanifest" },
            url = "https://json.schemastore.org/web-manifest-combined.json",
          },
          {
            fileMatch = { "tsconfig*.json" },
            url = "https://json.schemastore.org/tsconfig.json",
          },
          {
            fileMatch = {
              ".prettierrc",
              ".prettierrc.json",
              "prettier.config.json",
            },
            url = "https://json.schemastore.org/prettierrc.json",
          },
          {
            fileMatch = { ".eslintrc", ".eslintrc.json" },
            url = "https://json.schemastore.org/eslintrc.json",
          },
          {
            fileMatch = { ".babelrc", ".babelrc.json", "babel.config.json" },
            url = "https://json.schemastore.org/babelrc.json",
          },
          {
            fileMatch = { "lerna.json" },
            url = "https://json.schemastore.org/lerna.json",
          },
          {
            fileMatch = { "now.json", "vercel.json" },
            url = "https://json.schemastore.org/now.json",
          },
          {
            fileMatch = {
              ".stylelintrc",
              ".stylelintrc.json",
              "stylelint.config.json",
            },
            url = "https://json.schemastore.org/stylelintrc.json",
          },
        },
      },
    },
  })

  vim.lsp.config("denols", {
    handlers = { ["textDocument/definition"] = first_definition },
    root_markers = { "deno.json", "deno.jsonc" },
    init_options = { lint = true },
  })

  vim.lsp.config("lua_ls", {
    settings = {
      Lua = {
        runtime = {
          version = "LuaJIT",
        },
        telemetry = { enable = false },
        hint = { enable = true },
        workspace = {
          checkThirdParty = false,
          library = vim.api.nvim_get_runtime_file("", true),
        },
        codeLens = {
          enable = true,
        },
        diagnostics = {
          globals = { "vim" },
        },
        completion = {
          callSnippet = "Replace",
        },
      },
    },
  })

  vim.lsp.config("intelephense", {
    workspace_required = false,
  })

  vim.lsp.config("vimls", {
    init_options = { isNeovim = true },
  })

  -- Let Mason install servers without overriding our configurations.
  -- nvim-lspconfig's root callbacks keep TypeScript and Deno projects separate.
  require("mason-lspconfig").setup({ ensure_installed = servers, automatic_enable = false })
  vim.lsp.enable(servers)
end

return M
