return {
  {
    "neoclide/coc.nvim",
    branch = "release", -- Use the recommended release branch
    cond = function() return vim.fn.executable("npm") == 1 end, -- Only install if npm is available

    config = function()
      -- Ensure CoC is initialized properly
      vim.defer_fn(function()
        -- Run CocInstall command if it's not already installed
        local function install_coc_extension(extension)
          local status = vim.fn.system("nvim --headless +':CocList extensions' +qa")
          if not string.find(status, extension) then
            vim.cmd("CocInstall " .. extension)
          end
        end

        -- List of extensions to install
        local coc_extensions = { "coc-emmet", "coc-json", "coc-tsserver" }
        for _, ext in ipairs(coc_extensions) do
          install_coc_extension(ext)
        end
      end, 1000) -- Delay execution slightly to avoid issues
    end
  },
}
