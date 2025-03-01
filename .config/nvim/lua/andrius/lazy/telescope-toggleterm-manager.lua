return {
  "da-moon/telescope-toggleterm.nvim",
  dependencies = {
    "akinsho/toggleterm.nvim",
    "nvim-telescope/telescope.nvim",
    "nvim-lua/plenary.nvim",
  },
  config = function()
    require("telescope").load_extension("toggleterm")

    -- ToggleTerm configuration
    require("toggleterm").setup{
      size = 20,
      open_mapping = [[<leader>j]], -- Set <leader>j to toggle terminal
      hide_numbers = true,
      shade_filetypes = {},
      shade_terminals = true,
      shading_factor = 2,
      start_in_insert = true,
      insert_mappings = true,
      persist_size = true,
      -- direction = "float", -- You can change to 'horizontal' or 'vertical'
      close_on_exit = true,
      shell = vim.o.shell,
    }

    -- Telescope-ToggleTerm setup
    require("telescope-toggleterm").setup{
      telescope_mappings = {
        ["<C-c>"] = require("telescope-toggleterm").actions.exit_terminal,
      },
    }

    -- Keymap for Telescope-ToggleTerm picker
    vim.keymap.set("n", "<leader>tt", "<cmd>Telescope toggleterm<CR>", { noremap = true, silent = true })
  end,
}

