return {
    "akinsho/toggleterm.nvim",
    tag = "*",
    config = function()
        require("toggleterm").setup {
            start_in_insert = true,  -- Automatically enter insert mode
            direction = "float",     -- Use floating terminal (optional)
            open_mapping = [[<leader>t]],  -- This automatically maps <leader>t
        }

        -- Ensure <leader>t toggles the terminal (open/close)
        vim.keymap.set("n", "<leader>t", "<cmd>ToggleTermToggleAll<CR>", { noremap = true, silent = true })
    end
}

