return {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    lazy = false,
    build = ":TSUpdate",
    config = function()
        local ok_configs, configs = pcall(require, "nvim-treesitter.configs")
        if not ok_configs then
            vim.notify("nvim-treesitter not available yet", vim.log.levels.WARN, { title = "Treesitter" })
            return
        end

        local writable = vim.fn.filewritable(vim.fn.stdpath("data")) == 2

        -- When data dir is read-only (shared Plesk setup), redirect treesitter's
        -- install dir to a writable user path to suppress the read/write warning.
        -- Parsers already exist in the shared dir and are found via runtimepath.
        local parser_install_dir = nil
        if not writable then
            parser_install_dir = vim.fn.stdpath("cache") .. "/treesitter"
            vim.fn.mkdir(parser_install_dir .. "/parser", "p")
        end

        configs.setup({
            parser_install_dir = parser_install_dir,

            -- A list of parser names, or "all"
            ensure_installed = writable
                and { "vimdoc", "javascript", "typescript", "lua", "jsdoc", "bash", "php", "fish" }
                or {},

            -- Install parsers synchronously (only applied to `ensure_installed`)
            sync_install = false,

            -- Disable auto-install when data dir is read-only (shared Plesk setup)
            auto_install = writable,

            indent = {
                enable = true
            },

            highlight = {
                -- `false` will disable the whole extension
                enable = true,
                disable = function(lang, buf)
                    if lang == "html" then
                        print("disabled")
                        return true
                    end

                    local max_filesize = 100 * 1024 -- 100 KB
                    local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
                    if ok and stats and stats.size > max_filesize then
                        vim.notify(
                            "File larger than 100KB treesitter disabled for performance",
                            vim.log.levels.WARN,
                            {title = "Treesitter"}
                        )
                        return true
                    end
                end,

                -- Setting this to true will run `:h syntax` and tree-sitter at the same time.
                -- Set this to `true` if you depend on "syntax" being enabled (like for indentation).
                -- Using this option may slow down your editor, and you may see some duplicate highlights.
                -- Instead of true it can also be a list of languages
                additional_vim_regex_highlighting = { "markdown" },
            },
        })

        local ok_parsers, parsers = pcall(require, "nvim-treesitter.parsers")
        if not ok_parsers then
            vim.notify("nvim-treesitter parsers not available yet", vim.log.levels.WARN, { title = "Treesitter" })
            return
        end

        local treesitter_parser_config = parsers.get_parser_configs()
        treesitter_parser_config.templ = {
            install_info = {
                url = "https://github.com/vrischmann/tree-sitter-templ.git",
                files = {"src/parser.c", "src/scanner.c"},
                branch = "master",
            },
        }
        treesitter_parser_config.blade = {
            install_info = {
                url = "https://github.com/EmranMR/tree-sitter-blade",
                files = { "src/parser.c" },
                branch = "main",
            },
            filetype = "blade",
        }

        vim.treesitter.language.register("templ", "templ")
    end
}
