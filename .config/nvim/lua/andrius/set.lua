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
vim.opt.colorcolumn = "100"

if vim.fn.has("unix") == 1
   and vim.fn.readfile("/proc/sys/kernel/osrelease")[1]:lower():match("microsoft")
then
  -- Function that runs PowerShell, gets the clipboard, and strips CR (\r).
  local function wsl_paste()
    -- Call PowerShell from WSL to get the Windows clipboard content:
    local raw = vim.fn.system("powershell.exe -NoProfile -Command Get-Clipboard -Raw")
    -- Remove carriage returns:
    raw = raw:gsub("\r", "")
    -- Return it as a list of lines or a single multiline string:
    -- Typically returning a list of lines is recommended:
    return vim.split(raw, "\n", {plain=true})
  end

  vim.g.clipboard = {
    name = "WSLClipboard",
    copy = {
      ["+"] = "clip.exe",
      ["*"] = "clip.exe",
    },
    paste = {
      ["+"] = wsl_paste,
      ["*"] = wsl_paste,
    },
    cache_enabled = 0,
  }
end

