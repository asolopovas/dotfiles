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
      open_mapping = false, -- Disable default mapping, we'll create custom one
      hide_numbers = true,
      shade_filetypes = {},
      shade_terminals = true,
      shading_factor = 2,
      start_in_insert = true,
      insert_mappings = true,
      persist_size = true,
      direction = "horizontal", -- Open terminal horizontally at bottom
      close_on_exit = true,
      shell = vim.o.shell,
      winbar = {
        enabled = false,
      },
    }

    local terminal_state = {
      is_open = false,
      win_id = nil,
      buf_id = nil
    }

    -- Smart terminal toggle function
    local function smart_terminal_toggle()
      -- Check if terminal is already open
      if terminal_state.is_open and vim.api.nvim_win_is_valid(terminal_state.win_id) then
        -- Close terminal
        vim.api.nvim_win_close(terminal_state.win_id, false)
        terminal_state.is_open = false
        terminal_state.win_id = nil
        return
      end

      -- Check if nvim-tree is open
      local nvim_tree_wins = vim.tbl_filter(function(win)
        local buf = vim.api.nvim_win_get_buf(win)
        return vim.bo[buf].filetype == "NvimTree"
      end, vim.api.nvim_list_wins())
      
      if #nvim_tree_wins > 0 then
        -- Find the main content window
        local main_win = nil
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          local buf = vim.api.nvim_win_get_buf(win)
          if vim.bo[buf].filetype ~= "NvimTree" and vim.bo[buf].filetype ~= "toggleterm" then
            main_win = win
            break
          end
        end
        
        if main_win then
          -- Focus main window and create split
          vim.api.nvim_set_current_win(main_win)
          vim.cmd("split")
          vim.cmd("resize 20")
          
          -- Create or reuse terminal buffer
          if not terminal_state.buf_id or not vim.api.nvim_buf_is_valid(terminal_state.buf_id) then
            vim.cmd("terminal")
            terminal_state.buf_id = vim.api.nvim_get_current_buf()
          else
            -- Set existing terminal buffer in current window
            vim.api.nvim_win_set_buf(0, terminal_state.buf_id)
          end
          
          terminal_state.win_id = vim.api.nvim_get_current_win()
          terminal_state.is_open = true
          vim.cmd("startinsert")
        end
      else
        -- Normal behavior when nvim-tree is closed
        vim.cmd("ToggleTerm")
      end
    end

    -- Custom keymapping
    vim.keymap.set("n", "<C-j>", smart_terminal_toggle, { noremap = true, silent = true })
    vim.keymap.set("t", "<C-j>", smart_terminal_toggle, { noremap = true, silent = true })

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

