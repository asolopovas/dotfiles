return {
    "kylechui/nvim-surround",
    enabled = false, -- Temporarily disabled due to vim.cmd compatibility issue
    version = "v2.1.5", -- Pin to specific working version
    event = "VeryLazy",
    config = function()
        require("nvim-surround").setup({
            -- Configuration here, or leave empty to use defaults
        })
    end
}
