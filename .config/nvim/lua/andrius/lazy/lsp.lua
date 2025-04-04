return {
    "neovim/nvim-lspconfig",
    dependencies = {
        "stevearc/conform.nvim",
        "williamboman/mason.nvim",
        "williamboman/mason-lspconfig.nvim",
        "hrsh7th/cmp-nvim-lsp",
        "hrsh7th/cmp-buffer",
        "hrsh7th/cmp-path",
        "hrsh7th/cmp-cmdline",
        "hrsh7th/nvim-cmp",
        "L3MON4D3/LuaSnip",
        "saadparwaiz1/cmp_luasnip",
        "j-hui/fidget.nvim",
    },

    config = function()
        -- ======================
        --        Conform
        -- ======================
        require("conform").setup({
            formatters_by_ft = {
                -- add formatters if needed
            }
        })

        -- ======================
        --         CMP
        -- ======================
        local cmp = require('cmp')
        local cmp_lsp = require("cmp_nvim_lsp")
        local capabilities = vim.tbl_deep_extend(
            "force",
            {},
            vim.lsp.protocol.make_client_capabilities(),
            cmp_lsp.default_capabilities()
        )

        -- ======================
        --       Fidget
        -- ======================
        require("fidget").setup({})

        -- ======================
        --       Mason
        -- ======================
        require("mason").setup()

        -- ======================
        --   Mason LSP Config
        -- ======================
        require("mason-lspconfig").setup({
            ensure_installed = {
                "lua_ls",
                "intelephense",
                "jsonls",         -- <-- Add JSON LS here
            },
            handlers = {
                function(server_name) -- default handler (optional)
                    require("lspconfig")[server_name].setup {
                        capabilities = capabilities
                    }
                end,

                -- Lua
                ["lua_ls"] = function()
                    require("lspconfig").lua_ls.setup {
                        capabilities = capabilities,
                        settings = {
                            Lua = {
                                runtime = { version = "Lua 5.1" },
                                diagnostics = {
                                    globals = {
                                        "bit",
                                        "vim",
                                        "it",
                                        "describe",
                                        "before_each",
                                        "after_each"
                                    },
                                }
                            }
                        }
                    }
                end,

                -- PHP
                ["intelephense"] = function()
                    -- Get current working directory
                    local project_root = vim.loop.cwd()

                    local function is_wp_theme()
                        -- Get parent folder name
                        local parent_dir = vim.fn.fnamemodify(project_root, ":h:t")
                        return parent_dir == "themes"
                    end

                    local include_paths = {}
                    if is_wp_theme() then
                        include_paths = {
                            project_root .. "/../../../wp-includes",
                            project_root .. "/../../../wp-admin",
                            project_root .. "/../../plugins"
                        }
                    end

                    require("lspconfig").intelephense.setup {
                        capabilities = capabilities,
                        settings = {
                            intelephense = {
                                licenceKey = "~/licenses/intelephense.txt",
                                files = {
                                    maxSize = 10000000,
                                    associations = {
                                        "**/*.php",
                                    },
                                },
                                environment ={
                                    includePaths = include_paths
                                },
                                -- completion = {
                                --     fullyQualifyGlobalConstants = true,
                                --     triggerParameterHints = true
                                -- },
                                stubs = {
                                    "wordpress",
                                    "core",
                                    "date",
                                    "json",
                                    "pcre",
                                    "spl",
                                    "standard"
                                }
                            }
                        }
                    }
                end,

                -- JSON
                ["jsonls"] = function()
                    require("lspconfig").jsonls.setup {
                        capabilities = capabilities,
                        settings = {
                            json = {
                                -- This associates `composer.json` with the correct schema
                                schemas = {
                                    {
                                        description = "Composer configuration file",
                                        fileMatch = { "composer.json" },
                                        url = "https://raw.githubusercontent.com/composer/composer/master/composer-schema.json"
                                    },
                                },
                                validate = { enable = true },
                            },
                        },
                    }
                end
            }
        })

        -- ======================
        --       CMP Setup
        -- ======================
        local cmp_select = { behavior = cmp.SelectBehavior.Select }
        cmp.setup({
            snippet = {
                expand = function(args)
                    require('luasnip').lsp_expand(args.body)
                end,
            },
            mapping = cmp.mapping.preset.insert({
                ['<C-p>'] = cmp.mapping.select_prev_item(cmp_select),
                ['<C-n>'] = cmp.mapping.select_next_item(cmp_select),
                ['<C-y>'] = cmp.mapping.confirm({ select = true }),
                ['<C-Space>'] = cmp.mapping.complete(),
            }),
            sources = cmp.config.sources({
                { name = 'nvim_lsp' },
                { name = 'luasnip' },
            }, {
                    { name = 'buffer' },
                })
        })

        -- ======================
        -- Diagnostic settings
        -- ======================
        vim.diagnostic.config({
            float = {
                focusable = false,
                style = "minimal",
                border = "rounded",
                source = "always",
                header = "",
                prefix = "",
            },
        })
    end
}
