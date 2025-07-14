require("andrius.set")
require("andrius.remap")
require("andrius.lazy_init")
require('sg').setup()

local augroup = vim.api.nvim_create_augroup
local AUGroup = augroup('AUGroup', {})

local autocmd = vim.api.nvim_create_autocmd
local yank_group = augroup('HighlightYank', {})

function R(name)
    require("plenary.reload").reload_module(name)
end

vim.filetype.add({
    extension = {
        templ = 'templ',
    }
})

autocmd('TextYankPost', {
    group = yank_group,
    pattern = '*',
    callback = function()
        vim.highlight.on_yank({
            higroup = 'IncSearch',
            timeout = 40,
        })
    end,
})

autocmd('BufEnter', {
    group = AUGroup,
    callback = function()
        vim.cmd("colorscheme legacy")
    end
})

autocmd({"BufWritePre"}, {
    group = AUGroup,
    pattern = "*",
    command = [[%s/\s\+$//e]],
})

autocmd('LspAttach', {
    group = AUGroup,
    callback = function(e)
        local opts = { buffer = e.buf }
        vim.keymap.set("n", "gd", function() vim.lsp.buf.definition() end, opts)
        vim.keymap.set("n", "gb", "<C-o>", { noremap = false, silent = true })
        vim.keymap.set("n", "K", function() vim.lsp.buf.hover() end, opts)
        vim.keymap.set("n", "<leader>vws", function() vim.lsp.buf.workspace_symbol() end, opts)
        vim.keymap.set("n", "<leader>vca", function() vim.lsp.buf.code_action() end, opts)
        vim.keymap.set("n", "<leader>vrr", function() vim.lsp.buf.references() end, opts)
        vim.keymap.set("n", "<leader>vrn", function() vim.lsp.buf.rename() end, opts)
        vim.keymap.set("i", "<M-h>", function() vim.lsp.buf.signature_help() end, opts)
        vim.keymap.set("n", "[d", function() vim.diagnostic.goto_next() end, opts)
        vim.keymap.set("n", "]d", function() vim.diagnostic.goto_prev() end, opts)
    end
})

vim.g.netrw_browse_split = 0
vim.g.netrw_banner = 0
vim.g.netrw_winsize = 25
vim.g.nvim_tree_auto_open = 0

local parser_config = require "nvim-treesitter.parsers".get_parser_configs()
parser_config.blade = {
    install_info = {
        url = "https://github.com/EmranMR/tree-sitter-blade",
        files = { "src/parser.c" },
        branch = "main",
    },
    filetype = "blade"
}

vim.filetype.add({
    pattern = {
        ['.*%.blade%.php'] = 'blade',
    }
})
local bladeGrp
vim.api.nvim_create_augroup("BladeFiltypeRelated", { clear = true })

vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
    pattern = "*.blade.php",
    group = bladeGrp,
    callback = function()
        vim.opt.filetype = "blade"
    end,
})
vim.api.nvim_set_option("clipboard","unnamed,unnamedplus")


local function detect_browser()
  local is_wsl = vim.fn.has("wsl") == 1

  if is_wsl then
    return "wslview"  -- Windows browser for WSL
  elseif vim.fn.executable("xdg-open") == 1 then
    return "xdg-open"  -- Linux GUI
  else
    return nil  -- No browser available
  end
end

local browser = detect_browser()
if browser then
  vim.env.BROWSER = browser
end

