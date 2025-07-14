return {
   {
      "neoclide/coc.nvim",
      branch="release",
    cond = function() return vim.fn.executable("npm") == 1 end, -- Only install if npm is available
      config = function()
         utils = require("andrius.utils")
         utils.run_once("coc", function()
            vim.cmd([[:CocInstall coc-json coc-yaml coc-markdownlint coc-explorer coc-sh]])
            vim.cmd([[:CocInstall coc-lists coc-html coc-tsserver coc-go]])
         end)
      end
   }
}
