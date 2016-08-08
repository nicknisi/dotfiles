" source any .vimrc.local files in the cwd and recursively up
call applylocalsettings#ApplyLocalSettings(expand('.'))
