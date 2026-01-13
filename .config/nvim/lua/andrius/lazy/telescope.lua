return {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.5",
    dependencies = {
        "nvim-lua/plenary.nvim",
        {
            "nvim-telescope/telescope-fzf-native.nvim",
            build = "cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release",
        },
        "nvim-telescope/telescope-live-grep-args.nvim",
    },
    config = function()
        local telescope = require('telescope')
        local builtin = require('telescope.builtin')

        telescope.setup({
            defaults = {
                file_ignore_patterns = {
                    "node_modules/",
                    "vendor/",
                    "%.git/",
                    ".volta/*",
                    ".tmp/*",
                    ".bun/",
                    ".nuxt/",
                    ".npm/",
                    "logs/",
                    "wp-admin/",
                    "index.php",
                    "license.txt",
                    "test.code-workspace",
                    "test-results",
                    "types",
                    "wp-activate.php",
                    "wp-admin",
                    "wp-blog*",
                    "wp-comments-post",
                    "wp-cron.php",
                    "wp-includes",
                    "wp-links-opml*",
                    "wp-load*",
                    "wp-login*",
                    "wp-mail*",
                    "wp-signup*",
                    "wp-trackback*",
                    "xmlrpc.php",
                    "%.html$",
                    "%.csv$",
                    "wp-links*",
                    "wp-includes/",
                    "wp-content/themes/twentytwentyone/",
                    "wp-content/themes/twentytwentytwo/",
                    "wp-content/themes/twentytwentythree/",
                    "wp-content/themes/twentytwentyfour/",
                    "wp-content/plugins/(?!lyn%-blocks/)(?!modules/).*",
                    "storage/framework/",
                    "storage/logs/",
                    "storage/app/",
                    "synaptics",
                    "bootstrap/cache/",
                    "public/storage/",
                    "%.min%.js",
                    "%.min%.css",
                    "%.lock",
                    "composer%.lock",
                    "package%-lock%.json",
                    "yarn%.lock",
                    "%.log",
                    "%.tmp",
                    "%.cache",
                    "%.DS_Store",
                    "Thumbs%.db",
                },
            },
            extensions = {
                live_grep_args = {
                    auto_quoting = true,
                },
            }
        })

        telescope.load_extension('live_grep_args')

        local function smart_find_files()
            local dir = vim.fn.getcwd()
            while dir ~= "/" do
                if vim.fn.isdirectory(dir .. "/.git") == 1 then
                    builtin.git_files()
                    return
                end
                dir = vim.fn.fnamemodify(dir, ":h")
            end
            builtin.find_files()
        end

        local function preview_server_logs()
            builtin.find_files({
                prompt_title = "< Server Logs >",
                cwd = "/var/log",
                hidden = true,
                file_ignore_patterns = { "%.gz$", "%.xz$", "%.zip$", "%.tar$", "%.journal$" },
            })
        end

        local function grep_server_logs()
            telescope.extensions.live_grep_args.live_grep_args({
                prompt_title = "< Grep Server Logs >",
                cwd = "/var/log",
                additional_args = { "--hidden", "--no-ignore" },
                file_ignore_patterns = { "%.gz$", "%.xz$", "%.zip$", "%.tar$", "%.journal$" },
            })
        end

        -- Key mappings
        vim.keymap.set('n', '<C-p>', smart_find_files, {})
        vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
        vim.keymap.set('n', '<leader>fh', builtin.help_tags, {})
        vim.keymap.set('n', '<leader>fb', ":Telescope file_browser<cr>", {})
        vim.keymap.set('n', '<leader>fd', builtin.lsp_document_symbols, {})
        vim.keymap.set('n', '<leader>fs', builtin.lsp_workspace_symbols, {})

        -- live_grep_args mapping
        vim.keymap.set(
            'n',
            '<leader>fg',
            "<cmd>lua require('telescope').extensions.live_grep_args.live_grep_args()<CR>",
            { desc = "Live Grep" }
        )

        -- Logs key mappings (corrected)
        vim.keymap.set('n', '<leader>fl', preview_server_logs, { desc = "Preview Server Logs" })
        vim.keymap.set('n', '<leader>gl', grep_server_logs, { desc = "Live Grep Server Logs" })
    end
}
