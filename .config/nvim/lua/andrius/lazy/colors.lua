function ColorMyPencils(color)
	color = color or "legacy"
	vim.cmd("colorscheme " .. color)

	vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
	vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
end

return {
    {
        "erikbackman/brightburn.vim",
        config = function()
            ColorMyPencils("legacy")
        end
    }
}
