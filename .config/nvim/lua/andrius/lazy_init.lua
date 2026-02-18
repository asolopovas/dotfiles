local datadir = vim.fn.stdpath("data")
local lazypath = datadir .. "/lazy/lazy.nvim"

-- Ensure data directory exists so filewritable check works on first run
if vim.fn.isdirectory(datadir) == 0 then
    vim.fn.mkdir(datadir, "p")
end

local writable = vim.fn.filewritable(datadir) == 2

if not (vim.uv or vim.loop).fs_stat(lazypath) then
    if not writable then
        vim.notify("Shared nvim data not found: " .. lazypath, vim.log.levels.ERROR)
        return
    end
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable",
        lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    spec = {
        { import = "andrius.lazy" },
    },
    change_detection = { notify = false },
    rocks = { hererocks = true },
    install = { missing = writable },
    checker = { enabled = false },
})
