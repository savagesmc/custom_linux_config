
vim.keymap.set('n', "<leader>ne", ":NERDTreeToggle<CR>", { desc = "Toggle NERDTree" })

-- Use Space/Shift-Tab key to switch between tabs
vim.keymap.set('n', "<space>", "gt")
vim.keymap.set('n', "<S-Tab>", "gT")

-- Shortcut to split windows and move around between them
vim.keymap.set('n', "<leader>v", "<C-w>v<C-w>l")
vim.keymap.set('n', "<leader>s", "<C-w>s<C-w>j")
vim.keymap.set('n', "<C-h>", "<C-w>h")
vim.keymap.set('n', "<C-j>", "<C-w>j")
vim.keymap.set('n', "<C-l>", "<C-w>l")
vim.keymap.set('n', "<C-k>", "<C-w>k")

