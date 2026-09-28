# Workspace Names

An Omarchy bar widget that shows each Hyprland workspace as `number. app name`
instead of just the number, so you can see at a glance which app is on which
workspace. Empty workspaces keep the plain number.

```
1. 微信   2. Chromium   3. WPS   4. 终端   5. VS Code   ▪ 6. 终端
```

The active workspace keeps the built-in glyph indicator as a prefix.

## Install

```sh
omarchy plugin add https://github.com/zhuangbiaowei/omarchy-workspace-names.git --enable
```

Then place it on the bar (it defaults to the left section):

```sh
omarchy bar move io.github.zhuangbiaowei.workspace-names --section left
```

## Usage

- Left click a workspace to focus it.
- The label is `number. name` when the workspace has a window, and just
  `number` when it is empty.

## Names

The name comes from the focused window's app class. A small built-in map turns
common classes into friendly names (`foot` → 终端, `code` → VS Code, …).
Override or extend the map per class with a `labels` object in the widget's
`shell.json` entry:

```json
{
  "id": "io.github.zhuangbiaowei.workspace-names",
  "labels": { "code": "Editor", "foot": "Shell" }
}
```

Set `"showNames": false` to fall back to plain workspace numbers.

## Remove

```sh
omarchy plugin remove io.github.zhuangbiaowei.workspace-names
```

## Dependencies

None beyond Omarchy's own shell. No network access, no external commands at
install time. Clicking a workspace runs `hyprctl dispatch hl.dsp.focus(...)`.

## License

MIT. Derived from the Omarchy built-in `omarchy.workspaces` widget.
