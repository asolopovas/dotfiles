local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local writable = vim.fn.filewritable(vim.fn.stdpath("data")) == 2

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
