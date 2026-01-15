local fn = vim.fn

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({

  -- My plugins here
  {
    "folke/lazy.nvim"
  }, -- Have lazy manage itself

  {
    "nvim-lua/popup.nvim"
  }, -- An implementation of the Popup API from vim in Neovim

  {
    "nvim-lua/plenary.nvim"
  }, -- Useful lua functions used ny lots of plugins

  -- Neovim-Tmux Navigation
  {
    "alexghergh/nvim-tmux-navigation", config = function()

    local nvim_tmux_nav = require('nvim-tmux-navigation')

    nvim_tmux_nav.setup {
        disable_when_zoomed = true -- defaults to false
    }

    vim.keymap.set('n', "<C-h>", nvim_tmux_nav.NvimTmuxNavigateLeft)
    vim.keymap.set('n', "<C-j>", nvim_tmux_nav.NvimTmuxNavigateDown)
    vim.keymap.set('n', "<C-k>", nvim_tmux_nav.NvimTmuxNavigateUp)
    vim.keymap.set('n', "<C-l>", nvim_tmux_nav.NvimTmuxNavigateRight)
    vim.keymap.set('n', "<C-\\>", nvim_tmux_nav.NvimTmuxNavigateLastActive)
    vim.keymap.set('n', "<C-Space>", nvim_tmux_nav.NvimTmuxNavigateNext)

  end
  },

  -- Buffer Explorer
  {
    "jlanzarotta/bufexplorer"
  },

  -- NERDtree
  {
    "scrooloose/nerdtree",
    "Xuyuanp/nerdtree-git-plugin"
  },

  -- Colorschemes
  {
    "lunarvim/colorschemes"
  },

  -- vim.fugitive 
  {
    "tpope/vim-fugitive"
  },

  -- git signs
  {
    "lewis6991/gitsigns.nvim"
  },

  -- cmp plugins
  {
    "hrsh7th/nvim-cmp", -- The completion plugin
    "hrsh7th/cmp-buffer", -- buffer completions
    "hrsh7th/cmp-path", -- path completions
    "hrsh7th/cmp-cmdline", -- cmdline completions
    "saadparwaiz1/cmp_luasnip",-- snippet completions
    "hrsh7th/cmp-nvim-lsp",
    "hrsh7th/cmp-nvim-lua"
  },

  -- snippets
  {
    "L3MON4D3/LuaSnip", --snippet engine
    "rafamadriz/friendly-snippets", -- a bunch of snippets to use
  },

  -- LSP
  {
    "neovim/nvim-lspconfig", -- enable LSP
    "williamboman/mason.nvim", -- simple to use language server installer
    "williamboman/mason-lspconfig.nvim", -- simple to use language server installer
  },

  -- Markdown Preview
  ({
    "iamcco/markdown-preview.nvim",
    run = "cd app && npm install",
    setup = function()
      vim.g.mkdp_filetypes = { "markdown" }
    end,
    ft = { "markdown" },
  }),

  -- Telescope
  {
    "nvim-telescope/telescope.nvim",
    "nvim-telescope/telescope-media-files.nvim"
  },

  -- Treesitter
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
  },

  -- Comments
  {
    'numToStr/Comment.nvim',
    config = function()
        require('Comment').setup()
    end
  },

  -- gdb
  {
    "sakhnik/nvim-gdb"
  },

  -- Status Line (lualine)
  {
    'nvim-lualine/lualine.nvim',
    requires = { 'nvim-tree/nvim-web-devicons', opt = true }
  },

  -- DirDiff
  {
    "vim-scripts/DirDiff.vim"
  },

})

