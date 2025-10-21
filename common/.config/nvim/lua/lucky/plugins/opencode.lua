return {
  {
    'NickvanDyke/opencode.nvim',
    event = 'VeryLazy',
    dependencies = {
      { 'folke/snacks.nvim', opts = { input = {}, picker = {} } },
    },
    config = function()
      ---@type opencode.Opts
      vim.g.opencode_opts = {
        auto_reload = true,
      }
      -- auto_reload needs autoread so buffers update when opencode edits files
      vim.opt.autoread = true

      local map = function(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, { desc = 'Opencode: ' .. desc })
      end

      map({ 'n', 'x' }, '<leader>oa', function()
        require('opencode').ask('@this: ', { submit = true })
      end, 'Ask about this')
      map({ 'n', 'x' }, '<leader>os', function()
        require('opencode').select()
      end, 'Select prompt')
      map({ 'n', 'x' }, '<leader>o+', function()
        require('opencode').prompt('@this')
      end, 'Add this')
      map('n', '<leader>ot', function()
        require('opencode').toggle()
      end, 'Toggle embedded')
      map('n', '<leader>oc', function()
        require('opencode').command()
      end, 'Select command')
      map('n', '<leader>on', function()
        require('opencode').command('session_new')
      end, 'New session')
      map('n', '<leader>oi', function()
        require('opencode').command('session_interrupt')
      end, 'Interrupt session')
      map('n', '<leader>oA', function()
        require('opencode').command('agent_cycle')
      end, 'Cycle agent')
      map('n', '<S-C-u>', function()
        require('opencode').command('messages_half_page_up')
      end, 'Messages up')
      map('n', '<S-C-d>', function()
        require('opencode').command('messages_half_page_down')
      end, 'Messages down')
    end,
  },
}
