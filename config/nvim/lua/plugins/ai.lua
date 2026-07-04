---@type LazySpec
return {
    {
        "yetone/avante.nvim",
        enabled = false,
        opts = {
            provider = "opencode-go",
            providers = {
                ["opencode-go"] = {
                    __inherited_from = "openai",
                    endpoint = "https://opencode.ai/zen/go/v1",
                    model = "deepseek-v4-pro",
                    api_key_name = "OPENCODE_GO_API_KEY",
                    list_models = {
                        { id = "glm-5.1", name = "opencode-go: GLM-5.1" },
                        { id = "glm-5", name = "opencode-go: GLM-5" },
                        { id = "kimi-k2.7", name = "opencode-go: Kimi K2.7" },
                        { id = "kimi-k2.6", name = "opencode-go: Kimi K2.6" },
                        { id = "deepseek-v4-pro", name = "opencode-go: DeepSeek V4 Pro" },
                        { id = "deepseek-v4-flash", name = "opencode-go: DeepSeek V4 Flash" },
                        { id = "mimo-v2.5", name = "opencode-go: MiMo V2.5" },
                        { id = "mimo-v2.5-pro", name = "opencode-go: MiMo V2.5 Pro" },
                    },
                },
                ["opencode-anthropic"] = {
                    __inherited_from = "claude",
                    endpoint = "https://opencode.ai/zen/go",
                    model = "minimax-m3",
                    api_key_name = "OPENCODE_GO_API_KEY",
                    list_models = {
                        { id = "minimax-m3", name = "opencode-anthropic: MiniMax M3" },
                        { id = "minimax-m2.7", name = "opencode-anthropic: MiniMax M2.7" },
                        { id = "minimax-m2.5", name = "opencode-anthropic: MiniMax M2.5" },
                        { id = "qwen3.7-max", name = "opencode-anthropic: Qwen3.7 Max" },
                        { id = "qwen3.7-plus", name = "opencode-anthropic: Qwen3.7 Plus" },
                        { id = "qwen3.6-plus", name = "opencode-anthropic: Qwen3.6 Plus" },
                    },
                },
                claude = {
                    endpoint = "https://api.anthropic.com",
                    model = "claude-sonnet-4-20250514",
                    timeout = 30000,
                    extra_request_body = {
                        temperature = 0.75,
                        max_tokens = 20480,
                    },
                },
                openai = {
                    endpoint = "https://api.openai.com",
                    model = "gpt-4o",
                    timeout = 30000,
                },
                moonshot = {
                    endpoint = "https://api.moonshot.ai/v1",
                    model = "kimi-k2-0711-preview",
                    timeout = 30000,
                },
            },
        },
    },
}
