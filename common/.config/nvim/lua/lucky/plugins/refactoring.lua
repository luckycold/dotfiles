return {
  'ThePrimeagen/refactoring.nvim',
  dependencies = {
    'lewis6991/async.nvim',
    'nvim-treesitter/nvim-treesitter',
  },
  config = function()
    require('refactoring').setup {}

    vim.keymap.set({ 'n', 'x' }, '<leader>rr', function()
      require('refactoring').select_refactor()
    end, { desc = '[R]efactor select' })
    vim.keymap.set('x', '<leader>re', ':Refactor extract_func ', { desc = '[R]efactor [E]xtract function' })
    vim.keymap.set('x', '<leader>rf', ':Refactor extract_func_to_file ', { desc = '[R]efactor extract to [F]ile' })
    vim.keymap.set('x', '<leader>rv', ':Refactor extract_var ', { desc = '[R]efactor extract [V]ar' })
    vim.keymap.set({ 'n', 'x' }, '<leader>ri', ':Refactor inline_var', { desc = '[R]efactor [I]nline var' })
    vim.keymap.set('n', '<leader>rI', ':Refactor inline_func', { desc = '[R]efactor [I]nline func' })
    vim.keymap.set('n', '<leader>rb', ':Refactor extract_func', { desc = '[R]efactor extract [B]lock' })
    vim.keymap.set('n', '<leader>rbf', ':Refactor extract_func_to_file', { desc = '[R]efactor extract [B]lock to [F]ile' })
  end,
}
