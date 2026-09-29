import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
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

  // Friendly labels keyed by process name. Some XWayland applications open
  // helper windows that report no window class at all (WeChat's document
  // viewer, for instance); for those the only way to name the app is to look
  // at the process that owns the window. Keys are matched case-insensitively.
  readonly property var builtinProcessLabels: ({
    "wechat": "微信",
    "weixin": "微信",
    "wechat-universa": "微信",
    "wechat-universal": "微信",
    "wechatappex": "微信",
    "wps": "WPS",
    "wpspdf": "WPS",
    "wps-office": "WPS"
  })

  readonly property var labelOverrides: {
    var value = setting("labels", null)
    return (value && typeof value === "object") ? value : ({})
  }

  // Copied out of `hyprctl -j clients` (see clientsProc): workspace id ->
  // the toplevel Hyprland would call that workspace's last window. Reading
  // the compositor directly instead of the Quickshell workspace model is
  // deliberate: newly created windows do not reliably surface their class
  // through the per-workspace toplevel model, which left labels blank.
  property var workspaceClients: ({})

  // pid -> process name, used only for windows that report no class.
  property var processNames: ({})

  // Coalesces bursts of window events into a single snapshot refresh.
  property bool refreshQueued: false

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

  function labelForClass(cls) {
    if (!cls || cls.length === 0) return ""

    var over = labelOverrides[cls]
    if (over !== undefined) return String(over)

    var built = builtinLabels[cls]
    if (built !== undefined) return String(built)

    return cls
  }

  function labelForProcess(name) {
    if (!name || name.length === 0) return ""

    var over = labelOverrides[name]
    if (over !== undefined) return String(over)

    var lower = name.toLowerCase()
    var built = builtinProcessLabels[lower]
    if (built !== undefined) return String(built)

    // The kernel truncates process names to 15 characters, so also try the
    // class map against the truncated name before giving up.
    built = builtinLabels[lower]
    if (built !== undefined) return String(built)

    return name
  }

  // Human-readable name of the app occupying the workspace, or "" when empty.
  // Uses the app class when present; otherwise names the process that owns the
  // window. The window title is deliberately never used: titles are document
  // or page names ("...pdf", "... - Chromium"), not application names.
  function workspaceName(id) {
    var client = workspaceClients[id]
    if (!client) return ""

    if (client.class.length > 0) return labelForClass(client.class)

    var proc = client.pid >= 0 ? processNames[client.pid] : ""
    return labelForProcess(proc ? String(proc) : "")
  }

  // "1. Firefox" when occupied, plain "1" when the workspace has no windows.
  function workspaceLabel(id) {
    var number = (id === 10 ? "0" : String(id))
    if (setting("showNames", true) === false) return number

    var name = workspaceName(id)
    return name.length > 0 ? number + ". " + name : number
  }

  // Pick, per workspace, the client with the lowest focusHistoryID: the window
  // Hyprland reports as focused on that workspace.
  function applyClients(raw) {
    var listed
    try {
      listed = JSON.parse(raw || "[]")
    } catch (error) {
      return
    }
    if (!Array.isArray(listed)) return

    var best = ({})

    for (var i = 0; i < listed.length; i++) {
      var client = listed[i]
      if (!client || client.mapped === false) continue

      var workspace = client.workspace ? client.workspace.id : -1
      if (typeof workspace !== "number" || workspace <= 0) continue

      var order = (typeof client.focusHistoryID === "number") ? client.focusHistoryID : 100000 + i
      var previous = best[workspace]
      if (!previous || order < previous.order) {
        best[workspace] = {
          order: order,
          class: String(client.class || client.initialClass || ""),
          pid: (typeof client.pid === "number") ? client.pid : -1
        }
      }
    }

    workspaceClients = best
  }

  function applyProcessNames(raw) {
    var result = ({})
    var lines = String(raw || "").split("\n")

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (line.length === 0) continue

      var space = line.indexOf(" ")
      if (space <= 0) continue

      var pid = parseInt(line.slice(0, space), 10)
      var name = line.slice(space + 1).trim()
      if (!isNaN(pid) && name.length > 0) result[pid] = name
    }

    processNames = result
  }

  function refresh() {
    if (!clientsProc.running) clientsProc.running = true
    if (!processListProc.running) processListProc.running = true
  }

  // The compositor event arrives before anything else has caught up, so refresh
  // on the next event-loop turn. Bursts collapse into one refresh.
  function scheduleRefresh() {
    if (refreshQueued) return
    refreshQueued = true
    Qt.callLater(function() {
      root.refreshQueued = false
      root.refresh()
    })
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  Process {
    id: clientsProc
    command: ["hyprctl", "-j", "clients"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyClients(text)
    }
  }

  Process {
    id: processListProc
    command: ["ps", "-eo", "pid=,comm="]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyProcessNames(text)
    }
  }

  Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (!event || !event.name) return

      var name = String(event.name)
      if (name !== "openwindow" && name !== "closewindow" &&
          name !== "movewindow" && name !== "movewindowv2" &&
          name !== "windowtitle" && name !== "activewindow") return

      root.scheduleRefresh()
    }
  }

  // Safety net: catches anything the events above miss (and the initial load).
  Timer {
    interval: 3000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.scheduleRefresh()
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

        readonly property bool occupied: root.workspaceClients[modelData] !== undefined
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
