return {
  {
    "neoclide/coc.nvim",
    branch = "release",
    cond = function() return vim.fn.executable("npm") == 1 end, -- Ensure npm is available

    config = function()
      -- Define the path for a flag file to track installation
      local install_flag = vim.fn.stdpath("data") .. "/coc_installed"

      -- Function to install CoC extensions only if they are not already installed
      local function install_coc_extensions()
        if vim.fn.filereadable(install_flag) == 0 then
          vim.cmd("CocInstall -sync coc-emmet coc-json coc-tsserver | q")
          -- Create the flag file after installation
          vim.fn.writefile({}, install_flag)
        end
      end

      -- Delay execution to ensure `coc.nvim` is fully loaded
      vim.defer_fn(install_coc_extensions, 1000)
    end
  },
}
