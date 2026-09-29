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

The label is the application name, never the window title (which is a document
or page name such as `report.pdf` or `... - Chromium`). The name comes from, in
order:

1. the window's app class, mapped through a built-in table of friendly names
   (`foot` → 终端, `code` → VS Code, …);
2. when the window reports no class at all (some XWayland helper windows, such
   as WeChat's document viewer), the name of the process that owns the window,
   mapped through a built-in process table (`WeChatAppEx` → 微信).

The list of windows is read straight from the compositor (`hyprctl -j clients`)
whenever a window opens, closes, moves or changes workspace, with a periodic
safety refresh; process names come from `ps`.

Override or extend either table with a `labels` object in the widget's
`shell.json` entry (keys are window classes or process names):

```json
{
  "id": "io.github.zhuangbiaowei.workspace-names",
  "labels": { "code": "Editor", "foot": "Shell", "WeChatAppEx": "微信" }
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
