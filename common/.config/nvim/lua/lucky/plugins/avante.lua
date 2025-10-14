return {
  'yetone/avante.nvim',
  -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
  -- ⚠️ must add this setting! ! !
  build = vim.fn.has 'win32' ~= 0 and 'powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false' or 'make',
  event = 'VeryLazy',
  version = false, -- Never set this value to "*"! Never!
  ---@module 'avante'
  ---@type avante.Config
  opts = {
    -- add any opts here
    -- this file can contain specific instructions for your project
    instructions_file = 'avante.md',
    -- for example
    web_search_engine = {
      provider = 'brave',
      proxy = nil,
    },
    provider = 'codex',
    auto_suggestions_provider = 'z',
    acp_providers = {
      ['codex'] = {
        command = 'codex-acp',
        args = { 'quiet' },
        env = {
          RUST_LOG = 'error',
        },
      },
    },
    providers = {
      openai = {
        __inherited_from = 'openai',
        endpoint = 'https://openrouter.ai/api/v1',
        api_key_name = 'OPENROUTER_API_KEY',
        model = 'openai/gpt-5-codex',
      },
      anthropic = {
        __inherited_from = 'openai',
        endpoint = 'https://openrouter.ai/api/v1',
        api_key_name = 'OPENROUTER_API_KEY',
        model = 'anthropic/sonnet-4.7',
      },
      z = {
        __inherited_from = 'openai',
        endpoint = 'https://openrouter.ai/api/v1',
        api_key_name = 'OPENROUTER_API_KEY',
        model = 'z-ai/glm-4.6',
      },
      x = {
        __inherited_from = 'openai',
        endpoint = 'https://openrouter.ai/api/v1',
        api_key_name = 'OPENROUTER_API_KEY',
        model = 'x-ai/grok-4-fast',
      },
    },
  },
  rag_service = { -- RAG Service configuration
    enabled = false, -- Enables the RAG service
    host_mount = os.getenv 'HOME', -- Host mount path for the rag service (Docker will mount this path)
    runner = 'docker', -- Runner for the RAG service (can use docker or nix)
    llm = { -- Language Model (LLM) configuration for RAG service
      provider = 'openai', -- LLM provider
      endpoint = 'https://api.openai.com/v1', -- LLM API endpoint
      api_key = 'OPENAI_API_KEY', -- Environment variable name for the LLM API key
      model = 'gpt-4o-mini', -- LLM model name
      extra = nil, -- Additional configuration options for LLM
    },
    embed = { -- Embedding model configuration for RAG service
      provider = 'openai', -- Embedding provider
      endpoint = 'https://api.openai.com/v1', -- Embedding API endpoint
      api_key = 'OPENAI_API_KEY', -- Environment variable name for the embedding API key
      model = 'text-embedding-3-large', -- Embedding model name
      extra = nil, -- Additional configuration options for the embedding model
    },
    docker_extra_args = '', -- Extra arguments to pass to the docker command
  },
  dependencies = {
    'nvim-lua/plenary.nvim',
    'MunifTanjim/nui.nvim',
    --- The below dependencies are optional,
    'nvim-mini/mini.pick', -- for file_selector provider mini.pick
    'nvim-telescope/telescope.nvim', -- for file_selector provider telescope
    'hrsh7th/nvim-cmp', -- autocompletion for avante commands and mentions
    'ibhagwan/fzf-lua', -- for file_selector provider fzf
    'stevearc/dressing.nvim', -- for input provider dressing
    'folke/snacks.nvim', -- for input provider snacks
    'nvim-tree/nvim-web-devicons', -- or echasnovski/mini.icons
    'zbirenbaum/copilot.lua', -- for providers='copilot'
    {
      -- support for image pasting
      'HakonHarnes/img-clip.nvim',
      event = 'VeryLazy',
      opts = {
        -- recommended settings
        default = {
          embed_image_as_base64 = false,
          prompt_for_file_name = false,
          drag_and_drop = {
            insert_mode = true,
          },
          -- required for Windows users
          use_absolute_path = true,
        },
      },
    },
    {
      -- Make sure to set this up properly if you have lazy=true
      'MeanderingProgrammer/render-markdown.nvim',
      opts = {
        file_types = { 'markdown', 'Avante' },
      },
      ft = { 'markdown', 'Avante' },
    },
  },
}
