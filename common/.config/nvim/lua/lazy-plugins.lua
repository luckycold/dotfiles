-- [[ Configure and install plugins ]]
--
--  To check the current status of your plugins, run
--    :Lazy
--
--  You can press `?` in this menu for help. Use `:q` to close the window
--
--  To update plugins you can run
--    :Lazy update
--
-- NOTE: Here is where you install your plugins.
require('lazy').setup({
  -- NOTE: Plugins can be added with a link (or for a github repo: 'owner/repo' link).
  'tpope/vim-sleuth', -- Detect tabstop and shiftwidth automatically

  -- NOTE: Plugins can also be added by using a table,
  -- with the first argument being the link and the following
  -- keys can be used to configure plugin behavior/loading/etc.
  --
  -- Use `opts = {}` to force a plugin to be loaded.
  --
  --  This is equivalent to:
  --    require('Comment').setup({})

  -- "gc" to comment visual regions/lines
  { 'numToStr/Comment.nvim', opts = {} },

  -- Here is a more advanced example where we pass configuration
  -- options to `gitsigns.nvim`. This is equivalent to the following Lua:
  --    require('gitsigns').setup({ ... })
  --
  -- See `:help gitsigns` to understand what the configuration keys do
  -- { -- Adds git related signs to the gutter, as well as utilities for managing changes
  --   'lewis6991/gitsigns.nvim',
  --   opts = {
  --     signs = {
  --       add = { text = '+' },
  --       change = { text = '~' },
  --       delete = { text = '_' },
  --       topdelete = { text = '‾' },
  --       changedelete = { text = '~' },
  --     },
  --   },
  -- },
  -- GitSigns is a plugin that shows pretty icons on the left for git repos
  -- And here is a modularized version of gitsigns where it's neatly put away in lucky/plugins
  require 'lucky/plugins/gitsigns',

  -- which-key is a vim hotkey helper until you learn what everything does
  -- Look inside which-key.lua for an example of running lua code when plugin is loaded
  require 'lucky/plugins/which-key',

  -- Telescope is a fuzzyfinder for everything in neovim from files to your workspace to your lsp, and more!
  -- Look inside telescope.lua for an example of a plugin that specifies dependencies,
  require 'lucky/plugins/telescope',

  -- An LSP is a language server protocal. It helps with things like sutocompletion and debugging of programming languages.
  -- Look inside lsp-config to see the components of how an LSP works including one of the dependencies Mason that downloads some for you.
  require 'lucky/plugins/lsp-config',

  -- Autoformat
  require 'lucky/plugins/conform',

  -- Code Snippets
  require 'lucky/plugins/cmp',

  -- Tokyo Night Theme
  require 'lucky/plugins/tokyonight',

  -- Highlight todo, notes, etc in comments
  require 'lucky/plugins/todo-comments',

  -- Collection of various small independent plugins/modules
  require 'lucky/plugins/mini',

  -- I think treesitter is better code highlighting and some extra stuff on top of it?
  require 'lucky/plugins/treesitter',

  -- Remove trailing whitespace and highlight them in red when typing
  require 'lucky/plugins/trim',

  -- ChatGPT in Neovim!
  require 'lucky/plugins/chatgpt',

  -- Refactoring (Originally got this for extracting functions)
  require 'lucky/plugins/refactoring',
  --  Here are some example plugins that have been included in the Kickstart repository.
  --  Uncomment any of the lines below to enable them (you will need to restart nvim).
  require 'lucky/plugins/cmake-tools',

  require 'lucky/plugins/overseer',

  require 'lucky/plugins/toggleterm',

  require 'lucky/plugins/avante',
  -- require 'kickstart.plugins.debug',
  -- require 'kickstart.plugins.indent_line',
  -- require 'kickstart.plugins.lint',
  -- require 'kickstart.plugins.autopairs',
  -- require 'kickstart.plugins.neo-tree',
  -- require 'kickstart.plugins.gitsigns', -- adds gitsigns recommend keymaps
}, {
  ui = {
    -- If you are using a Nerd Font: set icons to an empty table which will use the
    -- default lazy.nvim defined Nerd Font icons, otherwise define a unicode icons table
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  },
})

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
