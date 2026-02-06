return {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
        preset = "helix",
        delay = 300,
        icons = {
            mappings = false,
            group = "+",
            separator = " > ",
        },
        win = {
            border = "rounded",
            padding = { 1, 2 },
            title = true,
            title_pos = "center",
        },
        layout = {
            width = { min = 20 },
            spacing = 3,
        },
        spec = {
            { "<leader>b", group = "buffer" },
            { "<leader>e", group = "edit config" },
            { "<leader>f", group = "find/format" },
            { "<leader>g", group = "git/grep" },
            { "<leader>t", group = "tabs/terminal" },
            { "<leader>v", group = "splits/lsp" },
            { "<leader>p", desc = "paste (keep register)" },
            { "<leader>q", desc = "close all buffers" },
            { "<leader>u", desc = "undo tree" },
            { "<leader>h", desc = "prev buffer" },
            { "<leader>l", desc = "next buffer" },
            { "<leader>T", desc = "new empty buffer" },
            { "<leader><space>", desc = "clear search" },
        },
    },
}
