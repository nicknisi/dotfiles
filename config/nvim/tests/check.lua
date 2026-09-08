-- Run from the repo root: nvim --headless -i NONE -u config/nvim/tests/check.lua
local config_dir = vim.fs.dirname(vim.fs.dirname(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p")))
vim.opt.rtp:prepend(config_dir)
vim.env.DOTFILES = nil -- The config must also work outside the dotfiles shell.
local errors, failures, passed = {}, 0, 0
vim.api.nvim_create_autocmd("User", {
  pattern = "LazyDone",
  callback = function()
    vim.notify = function(msg, level)
      if level == vim.log.levels.ERROR then
        errors[#errors + 1] = tostring(msg)
      end
    end
  end,
})
require("nisi").setup({ python = true, copilot = false })

local function check(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
    io.stdout:write("PASS " .. name .. "\n")
  else
    failures = failures + 1
    io.stdout:write("FAIL " .. name .. ": " .. tostring(err) .. "\n")
  end
end

vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    vim.schedule(function()
      local temp = vim.fn.tempname()
      vim.fn.mkdir(temp, "p")
      check("lazy bootstrap path", function()
        assert(require("nisi").config.lazypath == vim.fn.stdpath("data") .. "/lazy/lazy.nvim")
      end)
      check("diff options", function()
        for _, option in ipairs({ "vertical", "iwhite", "algorithm:patience", "hiddenoff" }) do
          assert(vim.tbl_contains(vim.opt.diffopt:get(), option), "missing " .. option)
        end
      end)
      check("Lua highlighting on first file", function()
        vim.cmd.edit(config_dir .. "/init.lua")
        assert(vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()], "highlighter missing")
        assert(vim.bo.indentexpr ~= "", "indentexpr missing")
        assert(type(require("nvim-treesitter-textobjects.select").select_textobject) == "function")
        assert(vim.fn.maparg("af", "o") ~= "", "function text object missing")
      end)
      check("configured language servers enabled", function()
        for _, server in ipairs({ "lua_ls", "jsonls", "pylsp", "eslint", "gopls", "vimls" }) do
          assert(vim.lsp.is_enabled(server), server .. " disabled")
        end
      end)
      check("Lua language server attaches", function()
        assert(
          vim.wait(10000, function()
            return #vim.lsp.get_clients({ bufnr = 0, name = "lua_ls" }) > 0
          end),
          "lua_ls did not attach"
        )
      end)
      check("completion with Copilot disabled", function()
        for _, source in ipairs(require("blink.cmp.config").sources.default) do
          require("blink.cmp.sources.lib").get_provider_by_id(source)
        end
      end)
      check("global snippets reach completion", function()
        local opts = require("blink.cmp.config").sources.providers.snippets.opts or {}
        local registry = require("blink.cmp.sources.snippets.default.registry").new(opts)
        assert(
          vim.iter(registry:get_global_snippets()):any(function(snippet)
            return snippet.prefix == "lorem"
          end),
          "global.json snippets missing"
        )
      end)
      check("Telescope native sorter", function()
        assert(package.loaded["telescope._extensions.fzf"], "fzf extension not loaded")
        local sorter = require("telescope.config").values.file_sorter({})
        sorter:_init()
        assert(sorter:scoring_function("init", "init.lua") > 0)
        sorter:_destroy()
      end)
      check("raw grep extension", function()
        assert(type(require("telescope").extensions.live_grep_args.live_grep_args) == "function")
      end)
      check("Python debugger executable and mappings", function()
        vim.fn.writefile({}, temp .. "/example.py")
        vim.cmd.edit(temp .. "/example.py")
        local adapter
        require("dap").adapters.python(function(value)
          adapter = value
        end, { request = "launch" })
        assert(adapter and vim.fn.executable(adapter.command) == 1, "debug adapter executable missing")
        assert(vim.fn.maparg(",dt", "n") ~= "", "debug method mapping missing on first Python buffer")
        assert(vim.fn.maparg(",ds", "x") ~= "", "debug selection is not a visual mapping")
      end)
      check("Python formatting runs both tools", function()
        local names = vim.tbl_map(function(formatter)
          return formatter.name
        end, require("conform").list_formatters_to_run())
        assert(vim.deep_equal(names, { "black", "isort" }), vim.inspect(names))
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { "import sys", "import os", "", "print(  1  )" })
        vim.cmd("silent write")
        local lines = vim.fn.readfile(temp .. "/example.py")
        assert(lines[1] == "import os" and lines[2] == "import sys" and lines[4] == "print(1)", vim.inspect(lines))
      end)
      check("shell formatting keeps shfmt after shellcheck", function()
        vim.cmd.enew()
        vim.bo.filetype = "sh"
        local names = vim.tbl_map(function(formatter)
          return formatter.name
        end, require("conform").list_formatters_to_run())
        assert(vim.deep_equal(names, { "shellcheck", "shfmt" }), vim.inspect(names))
      end)
      check("common filetypes and highlight queries", function()
        for _, ft in ipairs({
          "lua",
          "python",
          "typescript",
          "typescriptreact",
          "json",
          "jsonc",
          "markdown",
          "mdx",
          "sh",
          "html",
          "css",
          "blade",
          "ruby",
          "rust",
          "yaml",
          "astro",
        }) do
          vim.cmd.enew()
          vim.bo.filetype = ft
          local parser = assert(vim.treesitter.get_parser(), ft .. " parser missing")
          parser:parse()
          assert(vim.treesitter.query.get(parser:lang(), "highlights"), ft .. " highlights missing")
        end
      end)
      check("TypeScript and Deno stay separate in one session", function()
        for _, project in ipairs({
          { "node", "package.json", "ts_ls", "denols" },
          { "deno", "deno.json", "denols", "ts_ls" },
        }) do
          local dir = temp .. "/" .. project[1]
          vim.fn.mkdir(dir, "p")
          vim.fn.writefile({ "{}" }, dir .. "/" .. project[2])
          vim.fn.writefile({ "export const value = 1;" }, dir .. "/index.ts")
          vim.cmd.edit(dir .. "/index.ts")
          assert(
            vim.wait(10000, function()
              return #vim.lsp.get_clients({ bufnr = 0, name = project[3] }) == 1
            end),
            project[3] .. " did not attach"
          )
          assert(#vim.lsp.get_clients({ bufnr = 0, name = project[4] }) == 0, "conflicting server attached")
        end
      end)
      check("JSON language server attaches", function()
        vim.cmd.edit(temp .. "/node/package.json")
        assert(
          vim.wait(5000, function()
            return #vim.lsp.get_clients({ bufnr = 0, name = "jsonls" }) == 1
          end),
          "jsonls did not attach"
        )
      end)
      check("Astro starts without a workspace TypeScript SDK", function()
        vim.cmd.edit(temp .. "/node/index.astro")
        assert(
          vim.wait(10000, function()
            for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0, name = "astro" })) do
              if client.initialized then
                return true
              end
            end
            return false
          end),
          "astro did not initialize"
        )
      end)
      check("JavaScript formatting on save", function()
        local path = temp .. "/node/format.js"
        vim.fn.writefile({ "const answer={value:1}" }, path)
        vim.cmd.edit(path)
        assert(#require("conform").list_formatters_to_run() == 1, "fallback formatters must not run together")
        vim.cmd("silent write")
        assert(vim.fn.readfile(path)[1] == "const answer = { value: 1 };", "JavaScript was not formatted")
      end)
      check("setup is idempotent", function()
        local colorscheme = require("nisi").config.colorscheme
        require("nisi").setup({ colorscheme = "not-a-colorscheme" })
        assert(require("nisi").config.colorscheme == colorscheme, "second setup changed the config")
      end)
      vim.wait(200)
      check("no plugin configuration errors", function()
        assert(#errors == 0, table.concat(errors, "\n"))
        local messages = vim.api.nvim_exec2("messages", { output = true }).output
        assert(not messages:match("E%d+:") and not messages:find("vim.schedule callback:", 1, true), messages)
      end)
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_get_name(buf):sub(1, #temp) == temp then
          vim.api.nvim_buf_delete(buf, { force = true })
        end
      end
      vim.fn.delete(temp, "rf")
      io.stdout:write(string.format("%d passed, %d failed\n", passed, failures))
      vim.cmd(failures == 0 and "qa!" or "cquit")
    end)
  end,
})
