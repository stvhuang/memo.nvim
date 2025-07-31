# memo.nvim

A minimal Neovim plugin for navigating a directory of interlinked markdown notes.

Scopes its behavior to markdown buffers inside a directory you designate, so it does not interfere with markdown files elsewhere.

## Requirements

- Neovim 0.10+
- `nvim-treesitter` with the `markdown` and `markdown_inline` parsers installed

## Installation

Using `vim.pack`:

```lua
vim.pack.add({
    { src = "https://github.com/stvhuang/memo.nvim" },
})

require("memo").setup({
    dir = "/path/to/note/dir",
})

```

## Configuration

```lua
require("memo").setup({
    dir = "/path/to/note/dir", -- required
    entry_point = "README.md", -- optional, default "README.md"
})
```

- `dir`: absolute path to the directory holding your notes.
  The plugin only attaches keymaps to markdown buffers whose resolved path lies under this directory (symlinks are followed).
- `entry_point`: the file `require("memo").open()` opens.
  Path is relative to `dir`.

## Keymaps

Set automatically (buffer-local) on markdown buffers inside `dir`:

| Key       | Action                                                        |
| --------- | ------------------------------------------------------------- |
| `<CR>`    | Follow the markdown link under the cursor (relative to file). |
| `<Tab>`   | Jump to the next inline link, wrapping at end of buffer.      |
| `<S-Tab>` | Jump to the previous inline link, wrapping at start.          |

After `<Tab>` / `<S-Tab>`, the target link is highlighted until the cursor moves.

## API

```lua
require("memo").open()
```

Opens `<dir>/<entry_point>`.
Useful to bind to a global keymap as the entry point into your notes:

```lua
vim.keymap.set("n", "<leader>n", require("memo").open, { desc = "open notes" })
```
