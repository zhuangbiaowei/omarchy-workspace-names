import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.zhuangbiaowei.workspace-names"

  // Friendly labels for window classes. Extend or override per class with a
  // "labels" object on this widget's shell.json entry, e.g.
  //   { "id": "io.github.zhuangbiaowei.workspace-names", "labels": { "code": "Editor" } }
  readonly property var builtinLabels: ({
    "wechat": "微信",
    "weixin": "微信",
    "qq": "QQ",
    "chromium": "Chromium",
    "google-chrome": "Chrome",
    "firefox": "Firefox",
    "wpsoffice": "WPS",
    "wps": "WPS",
    "code": "VS Code",
    "code-oss": "VS Code",
    "vscodium": "VSCodium",
    "cursor": "Cursor",
    "foot": "终端",
    "kitty": "终端",
    "ghostty": "终端",
    "alacritty": "终端",
    "telegram": "Telegram",
    "org.telegram.desktop": "Telegram",
    "discord": "Discord",
    "slack": "Slack",
    "spotify": "Spotify",
    "mpv": "MPV",
    "thunar": "文件",
    "nautilus": "文件",
    "zotero": "Zotero"
  })

  readonly property var labelOverrides: {
    var value = setting("labels", null)
    return (value && typeof value === "object") ? value : ({})
  }

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  function workspaceIds() {
    var ids = [1, 2, 3, 4, 5]
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0 && id <= 10 && ids.indexOf(id) === -1) ids.push(id)
    }

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  // The window Hyprland would report as this workspace's "last window":
  // the most recently focused toplevel on the workspace.
  function representativeToplevel(workspace) {
    if (workspace === null) return null

    var toplevels = workspace.toplevels.values
    var best = null
    var bestOrder = Number.MAX_VALUE

    for (var i = 0; i < toplevels.length; i++) {
      var ipc = toplevels[i].lastIpcObject || {}
      var order = (typeof ipc.focusHistoryID === "number") ? ipc.focusHistoryID : 100000 + i
      if (best === null || order < bestOrder) {
        best = toplevels[i]
        bestOrder = order
      }
    }

    return best
  }

  function labelForClass(cls) {
    if (!cls || cls.length === 0) return ""

    var over = labelOverrides[cls]
    if (over !== undefined) return String(over)

    var built = builtinLabels[cls]
    if (built !== undefined) return String(built)

    return cls
  }

  // Human-readable name of the app occupying the workspace, or "" when empty.
  function workspaceName(id) {
    var toplevel = representativeToplevel(workspaceById(id))
    if (toplevel === null) return ""

    var ipc = toplevel.lastIpcObject || {}
    var cls = ipc.class && ipc.class.length > 0
      ? ipc.class
      : (ipc.initialClass && ipc.initialClass.length > 0 ? ipc.initialClass : "")

    if (cls.length > 0) return labelForClass(cls)

    // No usable class (some XWayland apps): fall back to a trimmed title.
    var title = ipc.title || toplevel.title || ""
    if (title.length > 18) title = title.substring(0, 17) + "…"
    return title
  }

  // "1. Firefox" when occupied, plain "1" when the workspace has no windows.
  function workspaceLabel(id) {
    var number = (id === 10 ? "0" : String(id))
    if (setting("showNames", true) === false) return number

    var name = workspaceName(id)
    return name.length > 0 ? number + ". " + name : number
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  readonly property string activeGlyph: "\uDB85\uDCFB"

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.workspaceIds().length
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds()

      WidgetButton {
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData

        bar: root.bar
        // Horizontal bar shows the number plus the app name; the vertical bar
        // keeps the compact number/glyph form so it still fits. The active
        // workspace keeps its glyph as a prefix.
        text: root.vertical
          ? (focused ? root.activeGlyph : (modelData === 10 ? "0" : String(modelData)))
          : (focused ? root.activeGlyph + " " + root.workspaceLabel(modelData) : root.workspaceLabel(modelData))
        active: focused && !root.vertical
        opacity: occupied || focused ? 1 : 0.5
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : -1
        fixedHeight: root.barSize
        onPressed: function() { root.focusWorkspace(modelData) }
      }
    }
  }
}
