return {
  'linux-cultist/venv-selector.nvim',
  ft = 'python',
  keys = {
    {
      '<leader>sv',
      '<cmd>VenvSelect<cr>',
      desc = '[P]ython [V]env',
    },
  },
  opts = {
    options = {
      cached_venv_automatic_activation = true,
      require_lsp_activation = true,
      notify_user_on_venv_activation = false,
    },
  },
  config = function(_, opts)
    require('venv-selector').setup(opts)

    local resolve_dotvenv_python = function(bufnr)
      local file_path = vim.api.nvim_buf_get_name(bufnr)
      if file_path == '' then
        return nil
      end

      local file_dir = vim.fs.dirname(file_path)
      if not file_dir then
        return nil
      end

      local venv_dir = vim.fs.find('.venv', {
        path = file_dir,
        upward = true,
        type = 'directory',
        limit = 1,
      })[1]

      if not venv_dir then
        return nil
      end

      local python_path = venv_dir .. '/bin/python'
      if vim.fn.executable(python_path) == 1 then
        return python_path
      end

      local windows_python_path = venv_dir .. '/Scripts/python.exe'
      if vim.fn.executable(windows_python_path) == 1 then
        return windows_python_path
      end

      return nil
    end

    vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile', 'FileType' }, {
      group = vim.api.nvim_create_augroup('venv-selector-dotvenv-default', { clear = true }),
      pattern = 'python',
      callback = function(event)
        vim.defer_fn(function()
          local bufnr = event.buf
          if not vim.api.nvim_buf_is_valid(bufnr) then
            return
          end

          if vim.bo[bufnr].buftype ~= '' or vim.bo[bufnr].filetype ~= 'python' then
            return
          end

          if vim.b[bufnr].venv_selector_disabled == true then
            return
          end

          if type(vim.b[bufnr].venv_selector_last_python) == 'string' and vim.b[bufnr].venv_selector_last_python ~= '' then
            return
          end

          local python_path = resolve_dotvenv_python(bufnr)
          if not python_path then
            return
          end

          require('venv-selector.venv').activate_for_buffer(python_path, 'venv', bufnr, { save_cache = true })
        end, 1200)
      end,
    })
  end,
}
