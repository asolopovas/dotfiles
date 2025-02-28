return {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.5",
    dependencies = {
        "nvim-lua/plenary.nvim",
    },
    config = function()
        require('telescope').setup({})

        local builtin = require('telescope.builtin')

        local function is_git_repo()
            local dir = vim.fn.getcwd()  -- Get current working directory
            while dir ~= "/" do
                if vim.fn.isdirectory(dir .. "/.git") == 1 then
                    return true
                end
                dir = vim.fn.fnamemodify(dir, ":h")  -- Move up one directory
            end
            return false
        end

        local function smart_find_files()
            if is_git_repo() then
                builtin.git_files()
            else
                builtin.find_files()
            end
        end

        -- Key mappings
        vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
        vim.keymap.set('n', '<C-p>', smart_find_files, {})
        vim.keymap.set('n', '<leader>pws', function()
            local word = vim.fn.expand("<cword>")
            builtin.grep_string({ search = word })
        end)
        vim.keymap.set('n', '<leader>pWs', function()
            local word = vim.fn.expand("<cWORD>")
            builtin.grep_string({ search = word })
        end)
            vim.keymap.set('n', '<leader>fg', function()
            builtin.grep_string({ search = vim.fn.input("Grep > ") })
        end)
        vim.keymap.set('n', '<leader>fh', builtin.help_tags, {})
        vim.keymap.set("n", "<leader>fb", ":Telescope file_browser<cr>", {})
        vim.keymap.set("n", "<leader>fg", builtin.live_grep, {})
        vim.keymap.set("n", "<leader>fd", builtin.lsp_document_symbols, {})
        vim.keymap.set("n", "<leader>fs", builtin.lsp_workspace_symbols, {})
    end
}
