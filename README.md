# Workspace Names

An Omarchy bar widget that shows each Hyprland workspace as `number. app name`
instead of just the number, so you can see at a glance which app is on which
workspace. Empty workspaces keep the plain number.

```
1. WeChat   2. Chromium   3. Files   4. Windows   5. Terminal   ▪ 6. Terminal
```

(The names follow the system locale, so `org.gnome.Nautilus` shows the same
name the launcher does — `Files` in an English locale, `文件` in Chinese.)

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
or page name such as `report.pdf` or `... - Chromium`). Each window is resolved
by trying, in order:

1. a `labels` override you set in `shell.json`;
2. a short built-in alias for classes whose real name is missing or unwieldy
   (`xfreerdp` → Windows, `wechat` → WeChat, `code-oss` → VS Code, …). The
   aliases are bilingual and selected by the session language
   (`xfreerdp` → `Windows` in English, `远程桌面` in Chinese);
3. the window's **desktop entry**, matched by application id (the file name
   without `.desktop`, e.g. `org.gnome.Nautilus`) or by the entry's declared
   `StartupWMClass` (e.g. `code` → `Code`). This is the name the system locale
   provides — the same one the launcher shows — so reverse-DNS classes like
   `org.gnome.Nautilus` become `Files`/`文件` instead of a raw id. Terminal
   emulators are shown by their generic name instead of the emulator's own name
   (a workspace running `foot`/`kitty`/`ghostty` reads `Terminal`, not `Foot`);
4. the process that owns the window (some XWayland helper windows report no
   class at all, such as WeChat's document viewer);
5. a prettified form of the class or process name (`com.spotify.Client` →
   `Spotify`), so a technical identifier is never shown verbatim.

The window list is read straight from the compositor (`hyprctl -j clients`)
whenever a window opens, closes, moves or changes workspace, with a periodic
safety refresh; process names come from `ps`, and names come from the desktop
entry database (`DesktopEntries`).

Override any of this — including the built-in aliases — with a `labels` object
in the widget's `shell.json` entry (keys are window classes or process names). A
value is either a plain string or a `{ "en": …, "zh": … }` object picked by the
session language:

```json
{
  "id": "io.github.zhuangbiaowei.workspace-names",
  "labels": { "code": "Editor", "foot": "Shell", "xfreerdp": { "en": "Windows", "zh": "远程桌面" } }
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
