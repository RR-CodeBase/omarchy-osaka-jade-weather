import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Optional bar widget: one toggle button per mood.
//
// Three buttons rather than one cycling icon, because the moods are
// independent and stack -- cycling would force you through states you did not
// ask for to reach the one you want. Lit means on, dimmed means off, so the
// whole state is readable at a glance instead of inferred from one glyph.
//
// It reads the same state file the service watches rather than shelling out to
// ask, so the buttons stay in step with the CLI, the keybindings and the menu
// without polling. Actions go through the bundled CLI by absolute path, so the
// widget works whether or not `osaka-weather` is on your PATH.
BarWidget {
  id: root
  moduleName: "io.github.rr-codebase.osaka-jade-weather"

  readonly property string cli:
    Qt.resolvedUrl("bin/osaka-weather").toString().replace(/^file:\/\//, "")

  property bool rain: false
  property bool day: false
  property bool night: false
  property bool fxEnabled: true
  property real intensity: 1.0

  implicitWidth: layout.implicitWidth
  implicitHeight: layout.implicitHeight

  function run(args) {
    if (root.bar) root.bar.run("'" + root.cli.replace(/'/g, "'\\''") + "' " + args)
  }

  FileView {
    id: stateFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/weather-fx.json"
    watchChanges: true
    printErrors: false
    onLoaded: {
      try {
        var cfg = JSON.parse(text() || "{}") || {}
        root.fxEnabled = cfg.enabled !== false
        root.rain = cfg.rain === true
        root.day = cfg.day === true
        root.night = cfg.night === true
        var n = Number(cfg.intensity)
        if (isFinite(n)) root.intensity = n
      } catch (error) {
        // A half-written file is transient; keep showing the last good state.
      }
    }
    onFileChanged: reload()
  }

  // Grid rather than Row/Column so one declaration serves a horizontal bar and
  // a vertical one.
  Grid {
    id: layout
    columns: root.vertical ? 1 : 3
    rows: root.vertical ? 3 : 1
    spacing: 0

    Repeater {
      model: [
        { key: "rain",  glyph: "󰖗", label: "Rain",     hint: "rain, mist and lightning" },
        { key: "day",   glyph: "󰖙", label: "Sunshine", hint: "sunlight, god rays and dust" },
        { key: "night", glyph: "󰖔", label: "Night",    hint: "stars, moonlight and fireflies" }
      ]

      BarIconButton {
        required property var modelData
        readonly property bool on: root.fxEnabled && root[modelData.key] === true

        bar: root.bar
        text: modelData.glyph

        // `active` paints bar.urgent, which is an alert colour and wrong for a
        // mood toggle. Use the theme accent, and lean on opacity to carry the
        // on/off state so it reads even where accent and foreground are close.
        active: on
        activeColor: Color.accent
        opacity: on ? 1.0 : 0.38
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        tooltipText: modelData.label + (on ? " — on" : " — off")
          + "\n" + modelData.hint
          + "\nClick: toggle · Middle: clear all · Scroll: intensity ("
          + root.intensity.toFixed(1) + ")"

        onPressed: function(b) {
          if (b === Qt.MiddleButton) root.run("clear")
          else root.run(modelData.key)
        }
        onWheelMoved: function(delta) {
          root.run(delta > 0 ? "intensity +0.1" : "intensity -0.1")
        }
      }
    }
  }
}
