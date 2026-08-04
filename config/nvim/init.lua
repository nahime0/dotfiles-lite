vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.smartindent = true

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.signcolumn = 'yes'
vim.opt.wrap = false
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.termguicolors = true
vim.opt.mouse = 'a'
vim.opt.confirm = true
vim.opt.undofile = true

local undo_dir = vim.fn.stdpath('data') .. '/undo'
vim.fn.mkdir(undo_dir, 'p')
vim.opt.undodir = undo_dir

if vim.fn.has('clipboard') == 1 then
    vim.opt.clipboard = 'unnamedplus'
end

vim.keymap.set('i', 'kj', '<Esc>', { desc = 'Leave insert mode' })
vim.keymap.set('n', '<leader>k', '<cmd>nohlsearch<CR>', { desc = 'Clear search highlights' })
vim.keymap.set('n', '<leader>j', '<cmd>bprevious<CR>', { desc = 'Previous buffer' })
vim.keymap.set('n', '<leader>l', '<cmd>bnext<CR>', { desc = 'Next buffer' })
vim.keymap.set('v', '<', '<gv')
vim.keymap.set('v', '>', '>gv')
vim.keymap.set('v', 'p', '"_dP')

local local_config = vim.fn.expand('~/.config/dotfiles-lite/nvim.local.lua')
if vim.fn.filereadable(local_config) == 1 then
    dofile(local_config)
end
