return {
  'jackMort/ChatGPT.nvim',
  event = 'VeryLazy',
  config = function()
    require('chatgpt').setup {
      api_key_cmd = 'echo $(bw get item e11ae8c1-6004-44fe-9b3f-b1b00113ef7f | jq -r \'.fields[] | select(.name == "Personal API Key") | .value\' -r',
    }
  end,
  dependencies = {
    'MunifTanjim/nui.nvim',
    'nvim-lua/plenary.nvim',
    'folke/trouble.nvim',
    'nvim-telescope/telescope.nvim',
  },
}
