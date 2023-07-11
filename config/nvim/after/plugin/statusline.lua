local lualine = require("lualine")

local function show_macro_recording()
  local recording_register = vim.fn.reg_recording()
  if recording_register == "" then
    return ""
  else
    return "Recording @" .. recording_register
  end
end

lualine.setup({
  options = {
    icons_enabled = true,
    theme = "catppuccin",
    section_separators = { right = "", left = "" },
    component_separators = "", --{ right = "", left = "" },
  },
  sections = {
    lualine_a = { { "mode" }, { "macro-recording", fmt = show_macro_recording } },
    lualine_b = {
      "branch",
      { "diff", symbols = { added = " ", modified = " ", removed = "󰮉 " } },
      "diagnostics",
    },
    lualine_c = { "filename", "searchcount" },
    lualine_x = { "fileformat", "filetype" },
    lualine_y = { "progress" },
    lualine_z = { "location" },
  },
})

vim.api.nvim_create_autocmd("RecordingEnter", {
  callback = function()
    -- refresh lualine when entering record mode
    lualine.refresh({ place = { "lualine_a" } })
  end,
})
