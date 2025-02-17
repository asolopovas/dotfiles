return {
  {
    "neoclide/coc.nvim",
    branch = "release", -- Use the recommended release branch
    cond = function() return vim.fn.executable("npm") == 1 end, -- Only install if npm is available
  },
}
