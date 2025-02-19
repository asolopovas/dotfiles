vim.opt.guicursor = ""
vim.opt.nu = true
vim.opt.relativenumber = true
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.wrap = false
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile = true
vim.opt.hlsearch = false
vim.opt.incsearch = true
vim.opt.termguicolors = true
vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.isfname:append("@-@")
vim.opt.updatetime = 50
vim.opt.colorcolumn = "90"

if vim.fn.has("unix") == 1 and vim.fn.readfile("/proc/sys/kernel/osrelease")[1]:lower():match("microsoft") then
    vim.g.clipboard = {
        name = "WSLClipboard",
        copy = {["+"] = "clip.exe", ["*"] = "clip.exe"},
        paste = {["+"] = "powershell.exe -c '[Console]::Out.Write($(Get-Clipboard) -replace \"\\r\", \"\")'",
                 ["*"] = "powershell.exe -c '[Console]::Out.Write($(Get-Clipboard) -replace \"\\r\", \"\")'"},
        cache_enabled = 0,
    }
else
    vim.o.clipboard = "unnamedplus"
end
