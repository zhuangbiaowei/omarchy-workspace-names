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

  // Session language, used to pick from the bilingual alias tables below: the
  // two-letter code of Qt's locale ("en", "zh", …), defaulting to English.
  readonly property string localeLanguage: {
    var match = String(Qt.locale().name || "").match(/^[A-Za-z]+/)
    return match ? match[0].toLowerCase() : "en"
  }

  // Resolve an alias value. A plain string is used as-is; an object is a
  // bilingual entry looked up by session language, falling back to "en" and
  // then to whatever language it does have.
  function localized(value) {
    if (value === undefined || value === null) return ""

    if (typeof value === "object") {
      var language = localeLanguage
      if (value[language] !== undefined) return String(value[language])
      if (value.en !== undefined) return String(value.en)
      for (var key in value) return String(value[key])
      return ""
    }

    return String(value)
  }

  // Short bilingual aliases that take precedence over the system name, used only
  // where the window class is an internal id and the registered name is missing
  // (xfreerdp has no desktop entry) or longer than useful ("WeChat (Universal)").
  // Everything else resolves through the desktop-entry database
  // (desktopEntryName) and therefore follows the system locale. Use the
  // "labels" setting for personal overrides instead of editing this table (a
  // string or the same { "en": …, "zh": … } shape both work):
  //   { "id": "io.github.zhuangbiaowei.workspace-names", "labels": { "foot": "Shell" } }
  readonly property var builtinLabels: ({
    "wechat": { "en": "WeChat", "zh": "微信" },
    "weixin": { "en": "WeChat", "zh": "微信" },
    "wechat-universa": { "en": "WeChat", "zh": "微信" },
    "wechat-universal": { "en": "WeChat", "zh": "微信" },
    "wechatappex": { "en": "WeChat", "zh": "微信" },
    "qq": { "en": "QQ", "zh": "QQ" },
    "telegram": { "en": "Telegram", "zh": "Telegram" },
    "org.telegram.desktop": { "en": "Telegram", "zh": "Telegram" },
    "google-chrome": { "en": "Google Chrome", "zh": "Chrome" },
    "code-oss": { "en": "VS Code", "zh": "VS Code" },
    "vscodium": { "en": "VSCodium", "zh": "VSCodium" },
    "cursor": { "en": "Cursor", "zh": "Cursor" },
    "xfreerdp": { "en": "Windows", "zh": "远程桌面" }
  })

  // Process-name aliases for XWayland applications whose helper windows report
  // no window class at all (WeChat's document viewer, for instance). Keys are
  // matched case-insensitively. Only consulted when the class yields nothing.
  readonly property var builtinProcessLabels: ({
    "wechat": { "en": "WeChat", "zh": "微信" },
    "weixin": { "en": "WeChat", "zh": "微信" },
    "wechat-universa": { "en": "WeChat", "zh": "微信" },
    "wechat-universal": { "en": "WeChat", "zh": "微信" },
    "wechatappex": { "en": "WeChat", "zh": "微信" },
    "wps": { "en": "WPS", "zh": "WPS" },
    "wpspdf": { "en": "WPS", "zh": "WPS" },
    "wps-office": { "en": "WPS", "zh": "WPS" }
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

  // Bumped when the desktop-entry database changes. Label bindings read it so
  // they re-resolve once the entry list has loaded, or when an app is
  // installed while the shell is running.
  property int desktopEntriesRevision: 0

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

  // Turns one window class or process name into a display name, or "" when the
  // key carries no readable name of its own.
  function resolveLabel(value) {
    if (!value || value.length === 0) return ""

    var over = labelOverrides[value]
    if (over !== undefined) return localized(over)

    var lower = value.toLowerCase()
    over = labelOverrides[lower]
    if (over !== undefined) return localized(over)

    var built = builtinLabels[value]
    if (built !== undefined) return localized(built)

    built = builtinProcessLabels[lower]
    if (built !== undefined) return localized(built)

    // The kernel truncates process names to 15 characters, so also try the
    // class map against the truncated name before giving up.
    built = builtinLabels[lower]
    if (built !== undefined) return localized(built)

    return desktopEntryName(value)
  }

  // The (localized) human name from the desktop-entry database. A window class
  // is frequently a reverse-DNS application id (org.gnome.Nautilus) whose
  // desktop entry is what actually carries the name (Files / 文件).
  function desktopEntryName(value) {
    if (!value || value.length === 0) return ""

    // Read the revision so QML bindings re-resolve when the entry list changes.
    var revision = desktopEntriesRevision

    var values = []
    try {
      values = DesktopEntries.applications.values || []
    } catch (error) {
      return ""
    }

    var lower = value.toLowerCase()

    // 1. Desktop-file id (the file name without .desktop): org.gnome.Nautilus.
    for (var i = 0; i < values.length; i++) {
      if (String(values[i].id || "").toLowerCase() === lower) {
        var byId = desktopEntryLabel(values[i])
        if (byId.length > 0) return byId
      }
    }

    // 2. Declared StartupWMClass (case-insensitive): code -> Code.
    for (var j = 0; j < values.length; j++) {
      var entry = values[j]
      if (String(entry.startupClass || "").toLowerCase() === lower) {
        var byClass = desktopEntryLabel(entry)
        if (byClass.length > 0) return byClass
      }
    }

    return ""
  }

  // Display name for a desktop entry. Terminal emulators are shown by their
  // generic name (Terminal) rather than the emulator's own name (Foot, Kitty),
  // because on the bar the useful fact is that the workspace holds a terminal.
  // Everything else keeps its proper name (chromium -> Chromium, not "Web
  // Browser"). `categories` is compared as text so it works whether it arrives
  // as a list or a semicolon-separated string.
  function desktopEntryLabel(entry) {
    if (!entry) return ""

    var generic = String(entry.genericName || "").trim()
    var categories = String(entry.categories || "")
    if (generic.length > 0 && categories.indexOf("TerminalEmulator") !== -1) return generic

    var name = String(entry.name || "").trim()
    if (name.length > 0) return name

    return generic
  }

  // Trailing namespace segments that name the packaging, not the app.
  readonly property var genericNameSegments: ({
    "desktop": true,
    "client": true,
    "app": true,
    "application": true,
    "bin": true,
    "linux": true,
    "gtk": true,
    "qt": true,
    "gui": true
  })

  // Presentable form of a class or process name that has no override and no
  // desktop entry, so a technical identifier is never shown verbatim. Drops a
  // trailing namespace segment (com.spotify.Client -> Spotify) and splits
  // dashes and camelCase.
  function prettifyName(value) {
    var text = String(value || "").trim()
    if (text.length === 0) return ""

    var parts = text.split(".")
    for (var i = parts.length - 1; i >= 0; i--) {
      var segment = parts[i].trim()
      if (segment.length > 0 && genericNameSegments[segment.toLowerCase()] !== true) {
        text = segment
        break
      }
    }

    text = text.replace(/[-_]+/g, " ").replace(/([a-z0-9])([A-Z])/g, "$1 $2").trim()
    if (text.length === 0) return String(value || "")
    return text.charAt(0).toUpperCase() + text.slice(1)
  }

  // Human-readable name of the app occupying the workspace, or "" when empty.
  // Uses the app class when it resolves; otherwise falls back to the process
  // that owns the window, then to a prettified class. The window title is
  // deliberately never used: titles are document or page names ("...pdf",
  // "... - Chromium"), not application names.
  function workspaceName(id) {
    var client = workspaceClients[id]
    if (!client) return ""

    var cls = client.class ? String(client.class) : ""
    var proc = (client.pid >= 0 && processNames[client.pid]) ? String(processNames[client.pid]) : ""

    var label = resolveLabel(cls)
    if (label.length > 0) return label

    label = resolveLabel(proc)
    if (label.length > 0) return label

    if (cls.length > 0) return prettifyName(cls)
    if (proc.length > 0) return prettifyName(proc)
    return ""
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

  // The desktop-entry list loads asynchronously (and can grow while the shell
  // runs); re-resolve labels whenever it changes.
  Connections {
    target: DesktopEntries

    function onApplicationsChanged() {
      root.desktopEntriesRevision++
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
