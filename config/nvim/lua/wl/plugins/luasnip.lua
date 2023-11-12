return {
    {
        "L3MON4D3/LuaSnip",
        --https://github.com/rafamadriz/friendly-snippets/blob/main/snippets
        dependencies = "rafamadriz/friendly-snippets",
        -- follow latest release.
        -- there is a problem with appimage: https://github.com/L3MON4D3/LuaSnip/issues/759#issuecomment-1452027996
        version = "1.*",
        -- install jsregexp (optional!).
        -- build = "make install_jsregexp",
    },
}
