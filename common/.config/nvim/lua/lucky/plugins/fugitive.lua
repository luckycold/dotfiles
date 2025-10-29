return {
  'tpope/vim-fugitive',
  config = function()
    vim.keymap.set('n', '<leader>gs', vim.cmd.Git, { desc = 'Git Status' })

    local ThePrimeagen_Fugitive = vim.api.nvim_create_augroup('ThePrimeagen_Fugitive', {})

    local autocmd = vim.api.nvim_create_autocmd
    autocmd('BufWinEnter', {
      group = ThePrimeagen_Fugitive,
      pattern = '*',
      callback = function()
        if vim.bo.ft ~= 'fugitive' then
          return
        end

        local bufnr = vim.api.nvim_get_current_buf()
        local opts = { buffer = bufnr, remap = false }
        local function map(lhs, rhs, desc)
          vim.keymap.set('n', lhs, rhs, vim.tbl_extend('force', opts, { desc = desc }))
        end

        map('<leader>p', function()
          vim.cmd.Git 'push'
        end, 'Git Push')

        -- rebase always
        map('<leader>P', function()
          vim.cmd 'Git pull --rebase'
        end, 'Git Pull Rebase')

        -- NOTE: It allows me to easily set the branch i am pushing and any tracking
        -- needed if i did not set the branch up correctly
        map('<leader>t', ':Git push -u origin ', 'Git Push Track')
      end,
    })

    vim.keymap.set('n', 'gu', '<cmd>diffget //2<CR>', { desc = 'Git Diff Get Index' })
    vim.keymap.set('n', 'gh', '<cmd>diffget //3<CR>', { desc = 'Git Diff Get Head' })
  end,
}
