-- AstroCommunity: import any community modules here
-- We import this file in `lazy_setup.lua` before the `plugins/` folder.
-- This guarantees that the specs are processed before any user plugins.

---@type LazySpec
return {
    "AstroNvim/astrocommunity",
    { import = "astrocommunity.pack.lua" },
    { import = "astrocommunity.pack.python" },
    {
        import = "astrocommunity.colorscheme.onedarkpro-nvim",
    },
    { import = "astrocommunity.git.diffview-nvim" },
    { import = "astrocommunity.utility.noice-nvim" },
    { import = "astrocommunity.lsp.lspsaga-nvim" },
    { import = "astrocommunity.motion.nvim-surround" },
    { import = "astrocommunity.motion.flash-nvim" },
    { import = "astrocommunity.ai.avante-nvim" },
}
