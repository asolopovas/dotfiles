return {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" }, -- optional icons support
    config = function()
        require("nvim-tree").setup()
    end
}
