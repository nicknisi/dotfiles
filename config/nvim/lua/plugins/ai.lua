return {
    {
        "zbirenbaum/copilot.lua",
        cmd = "Copilot",
        build = ":Copilot auth",
        event = "BufReadPost",
        opts = {
            suggestion = { enabled = false },
            panel = { enabled = false },
        },
        specs = {
            "saghen/blink.cmp",
            optional = true,
            dependencies = { "giuxtaposition/blink-cmp-copilot" },
            opts = {
                sources = {
                    default = { "copilot" },
                    providers = {
                        copilot = {
                            name = "copilot",
                            module = "blink-cmp-copilot",
                            score_offset = 100,
                            async = true,
                        },
                    },
                },
            },
        },
    },
}
