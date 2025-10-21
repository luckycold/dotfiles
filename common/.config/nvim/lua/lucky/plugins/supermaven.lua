return {
  {
    'Supermaven-Inc/supermaven-nvim',
    event = 'InsertEnter',
    opts = {
      keymaps = {
        accept_suggestion = '<C-l>',
        accept_word = '<C-.>',
        accept_line = '<C-/>',
      },
    },
    config = function(_, opts)
      require('supermaven-nvim').setup(opts)
    end,
  },
}
