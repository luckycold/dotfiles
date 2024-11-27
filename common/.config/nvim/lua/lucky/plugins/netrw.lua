-- ~/.config/nvim/lua/plugins/netrw.lua
return {
  'nvim-lua/plenary.nvim',
  config = function()
    local function netrw_mapping()
      vim.keymap.set('n', 'c', 'c', { buffer = true })
      -- Add more mappings here
    end

    vim.api.nvim_create_autocmd('filetype', {
      pattern = 'netrw',
      callback = netrw_mapping,
    })
  end,
}
