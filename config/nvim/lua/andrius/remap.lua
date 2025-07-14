vim.g.mapleader = " "
-- vim.g.mapleader = ","

local map = vim.api.nvim_set_keymap

vim.keymap.set("n", "<leader>pv", "<cmd>Ex<CR>")

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
map('n', '<M-J>', '<<', opts)
map('n', '<M-K>', '>>', opts)
map('i', '<M-J>', '<C-D>', opts)
map('i', '<M-K>', '<C-T>', opts)

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
map('n', '<M-H>', ':tabprevious<CR>', opts)
map('n', '<M-L>', ':tabnext<CR>', opts)

-- Open a new empty buffer
map('n', '<leader>T', ':enew<CR>', opts)

-- Buffer switching
map('n', '<leader>l', ':bnext<CR>', opts)
map('n', '<leader>h', ':bprevious<CR>', opts)

-- Splits Management
vim.o.splitbelow = true
vim.o.splitright = true
map('n', '<M-h>', '<C-w>h', opts)
map('n', '<M-j>', '<C-w>j', opts)
map('n', '<M-k>', '<C-w>k', opts)
map('n', '<M-l>', '<C-w>l', opts)
map('n', '<leader>vh', ':split<CR>', opts)
map('n', '<leader>vv', ':vsplit<CR>', opts)

-- Resize split windows (using different keys to avoid terminal conflicts)
vim.keymap.set('n', '<C-M-h>', '<C-w><', opts)
vim.keymap.set('n', '<C-M-j>', '<C-w>-', opts)
vim.keymap.set('n', '<C-M-k>', '<C-w>+', opts)
vim.keymap.set('n', '<C-M-l>', '<C-w>>', opts)

-- Terminal window resize - Alt+Shift combinations (with known issue)
vim.api.nvim_create_autocmd("TermOpen", {
  callback = function()
    local buf = vim.api.nvim_get_current_buf()
    
    vim.keymap.set("t", "<M-S-h>", "<Cmd>vertical resize -2<CR>", 
      { silent = true, buffer = buf })
    vim.keymap.set("t", "<M-S-j>", "<Cmd>resize -2<CR>", 
      { silent = true, buffer = buf })
    vim.keymap.set("t", "<M-S-k>", "<Cmd>resize +2<CR>", 
      { silent = true, buffer = buf })
    vim.keymap.set("t", "<M-S-l>", "<Cmd>vertical resize +2<CR>", 
      { silent = true, buffer = buf })
  end
})

vim.keymap.set("n", "<leader>fml", "<cmd>CellularAutomaton make_it_rain<CR>")
vim.keymap.set("n", "<M-`>", ":NvimTreeToggle<CR>", { noremap = true, silent = true })
vim.keymap.set("t", "<M-`>", "<C-\\><C-n>:NvimTreeToggle<CR>", { noremap = true, silent = true })


-- Terminal pane navigation
vim.keymap.set("t", "<M-h>", "<C-\\><C-n><C-w>h", opts)
vim.keymap.set("t", "<M-j>", "<C-\\><C-n><C-w>j", opts)
vim.keymap.set("t", "<M-k>", "<C-\\><C-n><C-w>k", opts)
vim.keymap.set("t", "<M-l>", "<C-\\><C-n><C-w>l", opts)

-- Terminal kill mapping
vim.keymap.set("t", "<M-q>", "<C-\\><C-n>:bd!<CR>", opts)

-- Force quit nvim
vim.keymap.set("n", "<M-S-q>", ":qa!<CR>", opts)
vim.keymap.set("t", "<M-S-q>", "<C-\\><C-n>:qa!<CR>", opts)

-- Auto-enter terminal mode when switching to terminal buffers
vim.api.nvim_create_autocmd("BufEnter", {
  pattern = "term://*",
  command = "startinsert"
})

