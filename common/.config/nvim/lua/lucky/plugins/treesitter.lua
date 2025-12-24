return {
  "nvim-treesitter/nvim-treesitter",
  lazy = false, -- README: plugin does not support lazy-loading [web:17]
  build = ":TSUpdate",
  opts = {
    ensure_installed = { "bash", "c", "html", "lua", "luadoc", "markdown", "vim", "vimdoc" },
    auto_install = true,
    highlight = {
      enable = true,
      additional_vim_regex_highlighting = { "ruby" },
    },
    indent = { enable = true, disable = { "ruby" } },
  },
}
