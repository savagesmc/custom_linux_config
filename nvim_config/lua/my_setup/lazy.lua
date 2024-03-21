-- lazy.nvim bootstrap:start --
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
   vim.fn.system({
      "git",
      "clone",
      "--filter=blob:none",
      "https://github.com/folke/lazy.nvim.git",
      "--branch=stable", -- latest stable release
      lazypath,
   })
end
vim.opt.rtp:prepend(lazypath)
-- lazy.nvim bootstrap:end --

-- Example using a list of specs with the default options
vim.g.mapleader = "," -- Make sure to set `mapleader` before lazy so your mappings are correct
vim.g.maplocalleader = "\\" -- Same for `maplocalleader`

local plugins = {
   'folke/lazy.nvim',
   'olimorris/onedarkpro.nvim',
   'ctrlpvim/ctrlp.vim',
   'scrooloose/nerdtree',
   'scrooloose/nerdcommenter',
   'Xuyuanp/nerdtree-git-plugin',
   'jlanzarotta/bufexplorer',
   'tpope/vim-fugitive',
   'tpope/vim-surround',
   -- 'christoomey/vim-tmux-navigator',
   -- 'vim-scripts/DirDiff.vim',
   -- 'wesQ3/vim-windowswap',
   -- 'Valloric/YouCompleteMe',
   -- 'chrisbra/colorizer',
   -- 'tpope/vim-repeat',
   -- 'tpope/vim-markdown',
   -- 'powerline/fonts',
   -- 'vim-airline/vim-airline',
   -- 'vim-airline/vim-airline-themes',
   -- 'mhinz/vim-signify',
   -- 'godlygeek/tabular',
   -- 'chazy/cscope_maps',
}

   --{
       --'christoomey/vim-tmux-navigator',
      --cmd = {
	 --"TmuxNavigateLeft",
	 --"TmuxNavigateDown",
	 --"TmuxNavigateUp",
	 --"TmuxNavigateRight",
	 --"TmuxNavigatePrevious",
      --},
      --keys = {
	 --{ "<c-h", "<cmd><C-U>TmuxNavigateLeft<cr>" },
	 --{ "<c-j", "<cmd><C-U>TmuxNavigateDown<cr>" },
	 --{ "<c-k", "<cmd><C-U>TmuxNavigateUp<cr>" },
	 --{ "<c-l", "<cmd><C-U>TmuxNavigateRight<cr>" },
	 --{ "<c-\\", "<cmd><C-U>TmuxNavigatePrevious<cr>" },
      --},
   --},

local opts = {
   --
}

require("lazy").setup(plugins, opts)

