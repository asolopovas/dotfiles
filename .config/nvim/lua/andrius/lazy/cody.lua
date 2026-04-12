return {
  {
    "sourcegraph/sg.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = { "CodyChat", "CodyToggle", "SourcegraphSearch" },
    cond = function()
      return vim.env.SRC_ENDPOINT ~= nil and vim.env.SRC_ACCESS_TOKEN ~= nil
    end,
  },
}

