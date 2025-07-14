return {
    "mbbill/undotree",

    config = function()
        vim.keymap.set("n", "<leader>u", "<cmd>UndotreeToggle<CR>")
    end
}

