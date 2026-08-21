return {
  'nvim-treesitter/nvim-treesitter',
  branch = 'main',
  lazy = false,
  build = ':TSUpdate',
  config = function()
    -- Neovim 0.12 needs the rewritten `main` branch. `master` is archived and
    -- its query predicates crash the highlighter (`node:range()` on a nil value).
    local parsers = {
      'bash',
      'c',
      'diff',
      'html',
      'lua',
      'luadoc',
      'markdown',
      'markdown_inline',
      'python',
      'query',
      'vim',
      'vimdoc',
    }

    require('nvim-treesitter').install(parsers)

    ---@param buf integer
    ---@param language string
    local function treesitter_try_attach(buf, language)
      if not vim.treesitter.language.add(language) then
        return
      end

      vim.treesitter.start(buf, language)

      local ok, indent_query = pcall(vim.treesitter.query.get, language, 'indents')
      if ok and indent_query then
        vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end
    end

    vim.api.nvim_create_autocmd('FileType', {
      group = vim.api.nvim_create_augroup('lucky-treesitter', { clear = true }),
      callback = function(args)
        local buf, filetype = args.buf, args.match
        local language = vim.treesitter.language.get_lang(filetype)
        if not language then
          return
        end

        local ts = require 'nvim-treesitter'
        local installed = ts.get_installed 'parsers'
        if vim.tbl_contains(installed, language) then
          treesitter_try_attach(buf, language)
          return
        end

        local available = ts.get_available()
        if vim.tbl_contains(available, language) then
          ts.install(language):await(function()
            treesitter_try_attach(buf, language)
          end)
        else
          treesitter_try_attach(buf, language)
        end
      end,
    })
  end,
}
