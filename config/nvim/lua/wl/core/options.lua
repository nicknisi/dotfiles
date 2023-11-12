-- see: option-list in the command helper
local opt = vim.opt
opt.smartindent = true                      -- make indenting smarter again
opt.number = true                           -- set numbered lines
opt.relativenumber = true                   -- set relative numbered lines
opt.shiftwidth = 4                          -- the number of spaces inserted for each indentation
opt.clipboard:append("unnamedplus")         -- allows neovim to access the system clipboard
opt.backup = false                          -- creates a backup file
opt.fileencoding = "utf-8"                  -- the encoding written to a file
opt.hlsearch = true                         -- highlight all matches on previous search pattern
opt.splitbelow = true                       -- force all horizontal splits to go below current window
opt.splitright = true                       -- force all vertical splits to go to the right of current window
opt.swapfile = false                        -- creates a swapfile
opt.updatetime = 300                        -- faster completion (4000ms default)
opt.writebackup = false                     -- if a file is being edited by another program (or was written to file while editing with another program), it is not allowed to be edited
opt.expandtab = true                        -- convert tabs to spaces
opt.wrap = false                            -- display lines as one long line

local uv = vim.loop

--add system clipboard in wsl
local in_wsl = os.getenv("WSL_DISTRO_NAME")
if in_wsl then
    vim.cmd([[
        let g:clipboard = {
                    \   'name': 'WslClipboard',
                    \   'copy': {
                    \      '+': 'clip.exe',
                    \      '*': 'clip.exe',
                    \    },
                    \   'paste': {
                    \      '+': 'powershell.exe -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
                    \      '*': 'powershell.exe -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
                    \   },
                    \   'cache_enabled': 0,
                    \ }
    ]])
elseif uv.os_uname().sysname == 'Windows' then
    -- enable powershell emulator in windows
    local powershell_options = {
      shell = vim.fn.executable "pwsh" == 1 and "pwsh" or "powershell",
      shellcmdflag = "-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command [Console]::InputEncoding=[Console]::OutputEncoding=[System.Text.Encoding]::UTF8;",
      shellredir = "-RedirectStandardOutput %s -NoNewWindow -Wait",
      shellpipe = "2>&1 | Out-File -Encoding UTF8 %s; exit $LastExitCode",
      shellquote = "",
      shellxquote = "",
    }

    for option, value in pairs(powershell_options) do
      vim.opt[option] = value
    end
end

-- autoreload if content changes
vim.cmd([[
    aug _autoreload
        autocmd!
        au FocusGained,BufEnter * :checktime
    aug end
]])
