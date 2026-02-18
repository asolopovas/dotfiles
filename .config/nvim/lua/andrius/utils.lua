local mod = {}

function mod.run_once(name, fn)
    -- Use state dir for marker files (writable even when data dir is shared/read-only)
    local state_dir = vim.fn.stdpath("state") .. "/post_installs"
    local post_install_file = state_dir .. "/" .. name

    -- Also check legacy data dir location for backwards compat
    local legacy_file = vim.fn.stdpath("data") .. "/post_installs/" .. name
    if vim.fn.filereadable(post_install_file) == 1
        or vim.fn.filereadable(legacy_file) == 1 then
        return
    end

    fn()

    -- Write marker to state dir (always writable)
    vim.fn.mkdir(state_dir, "p")
    local file = io.open(post_install_file, "w")
    if file then file:close() end
end

return mod
