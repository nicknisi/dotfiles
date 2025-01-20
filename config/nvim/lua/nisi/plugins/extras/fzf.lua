return {
  {
    "junegunn/fzf.vim",
    dependencies = { { dir = vim.env.HOMEBREW_PREFIX .. "/opt/fzf" } },
    config = function()
      local utils = require("nisi.utils")
      local imap = utils.imap

      -- Insert mode completion
      imap("<c-x><c-k>", "<plug>(fzf-complete-word)")
      imap("<c-x><c-f>", "<plug>(fzf-complete-path)")
      imap("<c-x><c-j>", "<plug>(fzf-complete-file-ag)")
      imap("<c-x><c-l>", "<plug>(fzf-complete-line)")

      vim.api.nvim_exec(
        [[
command! FZFMru call fzf#run({ 'source':  v:oldfiles, 'sink':    'e', 'options': '-m -x +s', 'down':    '40%'})
command! -bang -nargs=* Find call fzf#vim#grep('rg --column --line-number --no-heading --follow --color=always '.<q-args>.' || true', 1, <bang>0 ? fzf#vim#with_preview('up:60%') : fzf#vim#with_preview('right:50%:hidden', '?'), <bang>0)
command! -bang -nargs=? -complete=dir Files call fzf#vim#files(<q-args>, fzf#vim#with_preview(), <bang>0)
command! -bang -nargs=? -complete=dir GitFiles call fzf#vim#gitfiles(<q-args>, fzf#vim#with_preview(), <bang>0)
]],
        false
      )

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
