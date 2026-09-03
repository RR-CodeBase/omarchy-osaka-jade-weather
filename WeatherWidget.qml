import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar icon plus a popup panel, following the same shape as Omarchy's own
// audio and network panels: one BarIconButton for the bar, a KeyboardPanel
// anchored to it for the body.
//
// The icon reflects whatever is on; the panel holds a switch per mood and
// sliders for intensity and wind. Scrolling the bar icon still changes
// intensity without opening anything.
//
// State is read from the file the service watches rather than by shelling out,
// so the panel stays in step with the CLI, the keybindings and the menu.
// Actions go through the bundled CLI by absolute path, so this works whether or
// not `osaka-weather` is on the user's PATH.
Panel {
  id: root
  moduleName: "io.github.rr-codebase.osaka-jade-weather"
  ipcTarget: "io.github.rr-codebase.osaka-jade-weather"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  readonly property string cli:
    Qt.resolvedUrl("bin/osaka-weather").toString().replace(/^file:\/\//, "")

  property bool fxEnabled: true
  property bool rain: false
  property bool day: false
  property bool night: false
  property real intensity: 1.0
  property real wind: 0.0

  readonly property bool anyMood: fxEnabled && (rain || day || night)

  // Rain wins the icon: if it is raining that is the headline whatever else is
  // on. Then sun, then moon, then a dormant cloud.
  readonly property string glyph: !fxEnabled ? "󰖨"
    : rain ? "󰖗"
    : day ? "󰖙"
    : night ? "󰖔"
    : "󰖐"

  readonly property string moodName: {
    if (!fxEnabled) return "Weather off"
    if (rain && day && night) return "Everything at once"
    if (rain && day) return "Sun shower"
    if (rain && night) return "Night storm"
    if (rain) return "Rain"
    if (day && night) return "Golden hour"
    if (day) return "Sunshine"
    if (night) return "Night"
    return "Clear"
  }

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
        var i = Number(cfg.intensity); if (isFinite(i)) root.intensity = i
        var w = Number(cfg.wind); if (isFinite(w)) root.wind = w
      } catch (error) {
        // A half-written file is transient; keep the last good state.
      }
    }
    onFileChanged: reload()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.glyph
    active: root.anyMood
    activeColor: Color.accent
    tooltipText: root.moodName + "\nClick for weather · Scroll for intensity"
    onPressed: function(b) {
      if (b === Qt.MiddleButton) root.run("clear")
      else root.toggle()
    }
    onWheelMoved: function(delta) {
      root.run(delta > 0 ? "intensity +0.1" : "intensity -0.1")
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(300))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(520))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: panelColumn
        width: parent.width
        spacing: Style.spacing.controlGap

        PanelSectionHeader {
          text: root.moodName
          foreground: root.barForeground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        }

        // One switch per mood. They are independent and stack, so these are
        // switches rather than a radio group.
        Repeater {
          model: [
            { key: "rain",  glyph: "󰖗", label: "Rain" },
            { key: "day",   glyph: "󰖙", label: "Sunshine" },
            { key: "night", glyph: "󰖔", label: "Night" }
          ]

          Item {
            required property var modelData
            readonly property bool on: root[modelData.key] === true

            width: panelColumn.width
            height: Style.spacing.controlHeight

            Text {
              id: rowIcon
              text: modelData.glyph
              textFormat: Text.PlainText
              color: parent.on ? Color.accent : root.barForeground
              opacity: parent.on ? 1.0 : 0.55
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.icon
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              text: modelData.label
              textFormat: Text.PlainText
              color: root.barForeground
              opacity: parent.on ? 1.0 : 0.7
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
              anchors.left: rowIcon.right
              anchors.leftMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
            }

            ToggleSwitch {
              checked: parent.on
              foreground: root.barForeground
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              onToggled: root.run(modelData.key)
            }
          }
        }

        PanelSeparator {
          width: panelColumn.width
          foreground: root.barForeground
        }

        PanelSectionHeader {
          text: "Intensity  " + root.intensity.toFixed(1)
          foreground: root.barForeground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        }

        PanelSlider {
          bar: root.bar
          width: panelColumn.width
          minimum: 0.2
          maximum: 2.0
          step: 0.1
          value: root.intensity
          onMoved: function(v) { root.run("intensity " + v.toFixed(2)) }
        }

        PanelSectionHeader {
          text: "Wind  " + root.wind.toFixed(2)
          foreground: root.barForeground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        }

        PanelSlider {
          bar: root.bar
          width: panelColumn.width
          minimum: -1.0
          maximum: 1.0
          step: 0.05
          value: root.wind
          onMoved: function(v) { root.run("wind " + v.toFixed(2)) }
        }

        PanelSeparator {
          width: panelColumn.width
          foreground: root.barForeground
        }

        // Presets, for the combinations worth one click rather than three.
        Row {
          spacing: Style.spacing.controlGap

          Repeater {
            model: [
              { cmd: "clear",       glyph: "󰅖", tip: "Clear — all moods off" },
              { cmd: "storm",       glyph: "󰙾", tip: "Storm — heavy rain at night" },
              { cmd: "goldenhour",  glyph: "󰖚", tip: "Golden hour — sun and stars" },
              { cmd: "sync",        glyph: "󰖝", tip: "Match the real weather outside" },
              { cmd: "auto",        glyph: "󰃰", tip: "Follow the local sunrise and sunset" }
            ]

            PanelActionButton {
              required property var modelData
              iconText: modelData.glyph
              tooltipText: modelData.tip
              foreground: root.barForeground
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              onClicked: { root.run(modelData.cmd); root.close() }
            }
          }
        }
      }
    }
  }
}
