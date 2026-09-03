import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui

// Optional bar widget: shows the current mood and switches it.
//
// It reads the same state file the service watches rather than shelling out to
// ask, so the icon is live without polling a process. Actions go through the
// bundled CLI by absolute path, so the widget works whether or not the user
// put `osaka-weather` on their PATH.
BarWidget {
  id: root
  moduleName: "io.github.rr-codebase.osaka-jade-weather"

  readonly property string cli:
    Qt.resolvedUrl("bin/osaka-weather").toString().replace(/^file:\/\//, "")

  property bool rain: false
  property bool day: false
  property bool night: false
  property bool fxEnabled: true

  readonly property bool anyMood: fxEnabled && (rain || day || night)

  // Rain wins the icon: if it is raining, that is the headline whatever else
  // is on. Otherwise sun, then moon, then a dormant cloud.
  readonly property string glyph: !fxEnabled ? "󰖨"
    : rain ? "󰖗"
    : day ? "󰖙"
    : night ? "󰖔"
    : "󰖐"

  readonly property string moodName: {
    if (!fxEnabled) return "Weather off"
    if (rain && day && !night) return "Sun shower"
    if (rain && night && !day) return "Night storm"
    if (rain && day && night) return "Everything at once"
    if (rain) return "Rain"
    if (day && night) return "Golden hour"
    if (day) return "Sunshine"
    if (night) return "Night"
    return "Clear"
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

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
      } catch (error) {
        // A half-written file is transient; keep showing the last good state.
      }
    }
    onFileChanged: reload()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.glyph
    tooltipText: root.moodName +
      "\nClick: next mood · Right: rain · Middle: clear · Scroll: intensity"
    onPressed: function(b) {
      if (b === Qt.RightButton) root.run("rain")
      else if (b === Qt.MiddleButton) root.run("clear")
      else root.run("cycle")
    }
    onWheelMoved: function(delta) {
      root.run(delta > 0 ? "intensity +0.1" : "intensity -0.1")
    }
  }
}
