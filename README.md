# Dotfiles

A collection of my personal configurations and scripts for terminal tools, Tmux, Neovim, and more.

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/asolopovas/dotfiles/main/init.sh)"
```

## Terminal

|Shortcut|Description|
|---|---|
| `Ctrl + X E` | Edit command line |
| `Esc + B`    | Move one word back |
| `Esc + F`    | Move one word forward |

## Tmux

|Shortcut|Description|
|---|---|
| `Ctrl + A C`      | Create new window |
| `Ctrl + A ,`      | Rename window |
| `Ctrl + A P`      | Previous window |
| `Ctrl + A N`      | Next window |
| `Ctrl + A W`      | Select windows |
| `Ctrl + A %`      | Split vertically |
| `Ctrl + A :`      | Named commands |
| `Ctrl + A D`      | Detach from session |
| `Ctrl + A Alt+-`  | Horizontal Layout |
| `Ctrl + A Alt+\|` | Vertical Layout |

## Neovim

|Shortcut|Action|
|---|---|
| `Ctrl + V`       | Visual block mode |
| `Shift + >`      | Indent line |
| `Shift + N >`    | Indent line N steps |
| `F7`             | Reindent file |
| `Shift + { \| }` | Select lines between curly brackets |
| `vib \| cib`     | Select visual or change selection inside block |
| `ci} \| ci{`     | Select visual or change selection inside block |
| `Shift + { \| }` | Select lines between curly brackets |
| `m{letter}`      | Mark line (use capital letter for global marks) |
| `'{letter}`      | Jump to marked line |

<!-- Telescope -->
| Shortcut         | Action                                      |
|------------------|---------------------------------------------|
| `<C-p>`          | Smart file finder (`smart_find_files`) |
| `<leader>ff`     | Find files using Telescope's `find_files` |
| `<leader>fh`     | Search help tags |
| `<leader>fb`     | Open Telescope file browser |
| `<leader>fd`     | List document symbols from LSP |
| `<leader>fs`     | List workspace symbols from LSP |
| `<leader>fg`     | Live grep with arguments (`live_grep_args`) |

## Surround.vim plugin memo

| Old Text                     | Command       | New Text |
|------------------------------|--------------|----------|
| `surr*ound_words`            | `ysiw)`      | `(surround_words)` |
| `*make strings`              | `ys$"`       | `"make strings"` |
| `[delete ar*ound me!]`       | `ds]`        | `delete around me!` |
| `remove <b>HTML t*ags</b>`   | `dst`        | `remove HTML tags` |
| `'change quot*es'`           | `cs'"`       | `"change quotes"` |
| `<b>or tag* types</b>`       | `csth1<CR>`  | `<h1>or tag types</h1>` |
| `delete(functi*on calls)`    | `dsf`        | `function calls` |

