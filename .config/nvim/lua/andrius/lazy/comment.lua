return {
    'numToStr/Comment.nvim',
    opts = {
        toggler = {
            line = '<C-_>',  -- Maps Ctrl + / to toggle line comment
            block = '<C-S-_>', -- Maps Ctrl + Shift + / to toggle block comment
        },
        opleader = {
            line = '<C-_>',  -- Operator-pending mode for line comments
            block = '<C-S-_>', -- Operator-pending mode for block comments
        },
        mappings = {
            basic = true,  -- Enables default mappings
            extra = false, -- Disables extra mappings like `gcO`, `gco`, etc.
        },
    },
    config = function(_, opts)
        require("Comment").setup(opts)
        -- Manually set keymaps in normal and visual mode
        vim.api.nvim_set_keymap("n", "<C-_>", "gcc", { noremap = false, silent = true })
        vim.api.nvim_set_keymap("v", "<C-_>", "gc", { noremap = false, silent = true })
    end
}

