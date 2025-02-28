return {
    "akinsho/toggleterm.nvim",
    tag = "*",
    config = function()
        require("toggleterm").setup {
            -- Map <leader>t in normal mode to toggle the terminal
            open_mapping = [[m-t]],
            -- Optional: automatically enter insert mode when terminal opens
            start_in_insert = true,
        }
    end
}
