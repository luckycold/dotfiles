return {
  "nvim-treesitter/nvim-treesitter",
  branch = "master", -- README recommends pinning this for now [web:17]
  lazy = false,      -- README: plugin does not support lazy-loading [web:17]
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
  config = function(_, opts)
    require("nvim-treesitter.install").prefer_git = true
    require("nvim-treesitter.configs").setup(opts)
  end,
}
