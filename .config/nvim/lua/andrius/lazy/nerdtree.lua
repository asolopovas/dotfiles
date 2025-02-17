

return {
    "preservim/nerdtree",
    config = function()
        -- NERDTree Specific Settings
        vim.g.NERDTreeChDirMode = 2
        vim.g.NERDTreeHijackNetrw = 0
        vim.g.NERDTreeShowHidden = 1
        vim.g.nerdtree_tabs_open_on_console_startup = 1
        vim.g.NERDTreeDirArrows = 0

        -- Toggle NERDTree with ALT + `
        vim.api.nvim_set_keymap("n", "<M-`>", ":NERDTreeToggle<CR>", { noremap = true, silent = true })
    end
}

