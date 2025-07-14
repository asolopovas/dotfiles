local mod = {}

function mod.run_once(name, fn)
    local post_install_file = vim.fn.stdpath("data") .. "/post_installs/" .. name

    if vim.fn.filereadable(post_install_file) == 1 then
        return
    end

    fn()

    -- Create directory if it doesn't exist
    vim.fn.mkdir(vim.fn.fnamemodify(post_install_file, ":h"), "p")

    -- Create empty file
    local file = io.open(post_install_file, "w")
    file:close()
end

return mod
