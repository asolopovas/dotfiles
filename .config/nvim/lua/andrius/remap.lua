vim.g.mapleader = ","
vim.keymap.set("n", "<leader>pv", vim.cmd.Ex)

-- Key Mappings
local map = vim.api.nvim_set_keymap
local opts = { noremap = true, silent = true }

-- Auto format file
map('n', '<F7>', 'mzgg=G`z', opts)

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
map('n', '<leader>ev', ':e $MYVIMRC<CR>', opts)
map('n', '<leader>sv', ':so $MYVIMRC<CR>', opts)

-- Navigation improvements
map('n', 'j', 'gj', opts)
map('n', 'k', 'gk', opts)
map('n', '<C-d>', '<C-d>zz', opts)
map('n', '<C-u>', '<C-u>zz', opts)

-- Remove search highlighting
map('n', '<leader><space>', ':nohlsearch<CR>', opts)

-- Manage buffers
map('n', '<leader>bda', ':bufdo bd!<CR>', opts)
map('n', '<leader>bd', ':bd<CR>', opts)
map('n', '<leader>bq', ':bp | bd #<CR>', opts)

-- Tab management
map('n', '<leader>to', ':tabonly<CR>', opts)
map('n', '<leader>tw', ':tabclose<CR>', opts)
map('n', '<leader>tn', ':tabnew<CR>', opts)
map('n', '<F2>', ':tabprevious<CR>', opts)
map('n', '<F3>', ':tabnext<CR>', opts)

-- Open a new empty buffer
map('n', '<leader>T', ':enew<CR>', opts)

-- Buffer switching
map('n', '<leader>l', ':bnext<CR>', opts)
map('n', '<leader>h', ':bprevious<CR>', opts)

-- Quickfix Toggle
local quickfix_toggle = function()
    if vim.g.quickfix_is_open then
        vim.cmd('cclose')
        vim.g.quickfix_is_open = 0
    else
        vim.g.quickfix_is_open = 1
        vim.cmd('copen')
    end
end

vim.api.nvim_create_user_command('QuickfixToggle', quickfix_toggle, {})
map('n', '<leader>q', ':QuickfixToggle<CR>', opts)

-- Splits Management
vim.o.splitbelow = true
vim.o.splitright = true
map('n', '<C-h>', '<C-w>h', opts)
map('n', '<C-j>', '<C-w>j', opts)
map('n', '<C-k>', '<C-w>k', opts)
map('n', '<C-l>', '<C-w>l', opts)
map('n', '<leader>g', ':split<CR>', opts)
map('n', '<leader>v', ':vsplit<CR>', opts)

-- Resize split windows
map('n', '<C-Up>', '<C-w>-', opts)
map('n', '<C-Down>', '<C-w>+', opts)
map('n', '<C-Left>', '<C-w>>', opts)
map('n', '<C-Right>', '<C-w><', opts)

vim.keymap.set("n", "<leader>fml", "<cmd>CellularAutomaton make_it_rain<CR>")
