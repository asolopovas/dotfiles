vim.g.mapleader = " "
-- vim.g.mapleader = ","

local map = vim.api.nvim_set_keymap

vim.keymap.set("n", "<leader>pv", vim.cmd.Ex)

-- Move Selected Bock of Text
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")
vim.keymap.set("n", "J", "mzJ`z")

-- Place next item in center of screen
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

-- paste while retaining clipboard current value
vim.keymap.set("x", "<leader>p", [["_dP]])

-- Key Mappings
local opts = { noremap = true, silent = true }

-- Auto format file
map('n', '<leader>f', 'mzgg=G`z', opts)

-- Paste from clipboard using Shift+Insert
map('c', '<S-Insert>', '<C-R>+', {})

-- Save as sudo when needed
map('c', 'w!!', 'SudaWrite', {})

-- Toggle hidden characters
map('n', '<F5>', ':set list!<CR>', opts)
map('i', '<F5>', '<C-o>:set list!<CR>', opts)
map('c', '<F5>', '<C-c>:set list!<CR>', opts)

-- Indentation
map('x', '<', '<gv', opts)
map('x', '>', '>gv', opts)
map('n', '<M-j>', '<<', opts)
map('n', '<M-k>', '>>', opts)
map('i', '<M-j>', '<C-D>', opts)
map('i', '<M-k>', '<C-T>', opts)

-- Exit insert mode quickly
map('i', 'jk', '<Esc>', opts)

-- Edit common files
map('n', '<leader>er', ':e $HOME/.config/nvim/lua/andrius/remap.lua<CR>', opts)
map('n', '<leader>ev', ':e $HOME/.config/nvim/lua/andrius/init.lua<CR>', opts)
map('n', '<leader>es', ':e $HOME/.config/nvim/lua/andrius/set.lua<CR>', opts)
map('n', '<leader>ea', ':e $HOME/.config/.aliasrc<CR>', opts)
map('n', '<leader>sv', ':so $MYVIMRC<CR>', opts)
-- Open remap.lua instead of init.vim

-- Navigation improvements
map('n', 'j', 'gj', opts)
map('n', 'k', 'gk', opts)
map('n', '<C-d>', '<C-d>zz', opts)
map('n', '<C-u>', '<C-u>zz', opts)

-- Remove search highlighting
map('n', '<leader><space>', ':nohlsearch<CR>', opts)

-- Manage buffers
map('n', '<leader>q', ':bufdo bd!<CR>', opts)
map('n', '<leader>bd', ':bd<CR>', opts)
map('n', '<leader>bq', ':bp | bd #<CR>', opts)

-- Tab management
map('n', '<leader>to', ':tabonly<CR>', opts)
map('n', '<M-q>', ':tabclose<CR>', opts)
map('n', '<M-t>', ':tabnew<CR>', opts)
map('n', '<M-h>', ':tabprevious<CR>', opts)
map('n', '<M-l>', ':tabnext<CR>', opts)

-- Open a new empty buffer
map('n', '<leader>T', ':enew<CR>', opts)

-- Buffer switching
map('n', '<leader>l', ':bnext<CR>', opts)
map('n', '<leader>h', ':bprevious<CR>', opts)

-- Splits Management
vim.o.splitbelow = true
vim.o.splitright = true
map('n', '<C-h>', '<C-w>h', opts)
map('n', '<C-j>', '<C-w>j', opts)
map('n', '<C-k>', '<C-w>k', opts)
map('n', '<C-l>', '<C-w>l', opts)
map('n', '<leader>vh', ':split<CR>', opts)
map('n', '<leader>vv', ':vsplit<CR>', opts)

-- Resize split windows
map('n', '<C-Up>', '<C-w>-', opts)
map('n', '<C-Down>', '<C-w>+', opts)
map('n', '<C-Left>', '<C-w>>', opts)
map('n', '<C-Right>', '<C-w><', opts)

vim.keymap.set("n", "<leader>fml", "<cmd>CellularAutomaton make_it_rain<CR>")
vim.keymap.set("n", "<M-`>", ":NvimTreeToggle<CR>", { noremap = true, silent = true })

