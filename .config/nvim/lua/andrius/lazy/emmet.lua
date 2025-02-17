return {
  {
    "neoclide/coc.nvim",
    branch = "release", -- Use the recommended release branch
    build = "npm ci", -- Ensure dependencies are installed (only needed for master branch)
    cond = function() return vim.fn.executable("npm") == 1 end, -- Only install if npm is available
  },
}
