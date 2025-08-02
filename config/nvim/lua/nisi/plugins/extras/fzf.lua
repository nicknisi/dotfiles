return {
  {
    "junegunn/fzf.vim",
    dependencies = { { dir = vim.env.HOMEBREW_PREFIX .. "/opt/fzf" } },
    config = function()
      -- Insert mode completion
      vim.keymap.set("i", "<c-x><c-k>", "<plug>(fzf-complete-word)", { remap = true })
      vim.keymap.set("i", "<c-x><c-f>", "<plug>(fzf-complete-path)", { remap = true })
      vim.keymap.set("i", "<c-x><c-j>", "<plug>(fzf-complete-file-ag)", { remap = true })
      vim.keymap.set("i", "<c-x><c-l>", "<plug>(fzf-complete-line)", { remap = true })

      -- Create user commands using modern API
      vim.api.nvim_create_user_command("FZFMru", function()
        vim.fn["fzf#run"]({
          source = vim.v.oldfiles,
          sink = "e",
          options = "-m -x +s",
          down = "40%",
        })
      end, { desc = "Open FZF with most recently used files" })

      vim.api.nvim_create_user_command("Find", function(opts)
        local preview = opts.bang and "up:60%" or "right:50%:hidden"
        vim.fn["fzf#vim#grep"](
          "rg --column --line-number --no-heading --follow --color=always "
            .. vim.fn.shellescape(opts.args)
            .. " || true",
          1,
          vim.fn["fzf#vim#with_preview"](preview, "?"),
          opts.bang
        )
      end, { bang = true, nargs = "*", desc = "Find text using ripgrep" })

      vim.api.nvim_create_user_command("Files", function(opts)
        vim.fn["fzf#vim#files"](opts.args, vim.fn["fzf#vim#with_preview"](), opts.bang)
      end, { bang = true, nargs = "?", complete = "dir", desc = "Find files with FZF" })

      vim.api.nvim_create_user_command("GitFiles", function(opts)
        vim.fn["fzf#vim#gitfiles"](opts.args, vim.fn["fzf#vim#with_preview"](), opts.bang)
      end, { bang = true, nargs = "?", complete = "dir", desc = "Find git files with FZF" })

      function FloatingFZF()
        local lines = vim.o.lines
        local columns = vim.o.columns
        local buf = vim.api.nvim_create_buf(true, true)
        local height = vim.fn.float2nr(lines * 0.5)
        local width = vim.fn.float2nr(columns * 0.7)
        local horizontal = vim.fn.float2nr((columns - width) / 2)
        local vertical = 0
        local opts = {
          relative = "editor",
          row = vertical,
          col = horizontal,
          width = width,
          height = height,
          style = "minimal",
        }
        vim.api.nvim_open_win(buf, true, opts)
      end

      local fzf_opts = {
        vim.env.FZF_DEFAULT_OPTS or "",
        " --layout=reverse",
        ' --pointer=" "',
        " --info=hidden",
        " --border=rounded",
        " --bind å:select-all+accept",
      }

      vim.env.FZF_DEFAULT_OPTS = table.concat(fzf_opts, "")

      vim.g.fzf_preview_window = { "right:50%:hidden", "?" }
      vim.g.fzf_layout = { window = "call v:lua.FloatingFZF()" }
    end,
  },
  -- configure fzf to use telescope
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release && cmake --install build --prefix build",
      },
    },
    opts = {
      extensions = {
        fzf = {
          fuzzy = true,
          override_generic_sorter = true,
          override_file_sorter = true,
          case_mode = "smart_case",
        },
      },
    },
  },
}
