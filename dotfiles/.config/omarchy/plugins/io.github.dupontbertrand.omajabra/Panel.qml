import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

Panel {
  id: root

  moduleName: "io.github.dupontbertrand.omajabra"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  readonly property var jabraService: bar && bar.shell
    ? bar.shell.serviceFor(root.moduleName)
    : null
  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property color dim: Qt.darker(root.foreground, 1.5)
  readonly property color healthy: "#59d98e"
  readonly property color warning: "#f0b45a"
  readonly property color urgent: "#ef5f6b"
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool connected: jabraService ? jabraService.connected : false
  readonly property bool paired: jabraService ? jabraService.paired : false
  readonly property bool busy: jabraService ? jabraService.actionBusy : false

  function open() {
    if (root.jabraService) root.jabraService.refresh()
    root.controller.show()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  function profileLabel() {
    if (!root.jabraService) return "—"
    if (root.jabraService.profileMode === "music")
      return "Music" + (root.jabraService.codec ? " · " + root.jabraService.codec : "")
    if (root.jabraService.profileMode === "calls")
      return "Calls" + (root.jabraService.codec ? " · " + root.jabraService.codec : "")
    return root.jabraService.profile || "—"
  }

  function batteryText() {
    return root.jabraService && root.jabraService.batteryKnown
      ? Number(root.jabraService.battery) + "%" : "—"
  }

  component DetailRow: Item {
    property string label: ""
    property string value: ""

    width: parent ? parent.width : 0
    implicitHeight: Math.max(detailLabel.implicitHeight, detailValue.implicitHeight)

    Text {
      id: detailLabel
      text: parent.label
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      id: detailValue
      text: parent.value
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  component ActionButton: Button {
    bordered: true
    foreground: root.foreground
    fontFamily: root.fontFamily
    fontSize: Style.font.bodySmall
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (!root.jabraService) return
        if (text === "r" || text === "R") root.jabraService.refresh()
        else if (text === "m" || text === "M") root.jabraService.selectProfile("music")
        else if (text === "c" || text === "C") root.jabraService.selectProfile("calls")
      }

      Flickable {
        id: panelScroll
        anchors.fill: parent
        contentWidth: content.width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: content
          width: panelScroll.width
          spacing: Style.space(16)

          PanelHero {
            width: parent.width
            title: root.jabraService ? root.jabraService.deviceName : "Jabra"
            meta: root.jabraService ? root.jabraService.message : "Starting Omajabra…"
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconOpacity: root.connected ? 1.0 : 0.5
            iconComponent: Component {
              JabraIcon {
                iconSize: Style.font.display
                color: root.foreground
              }
            }
          }

          Column {
            width: parent.width
            spacing: Style.space(8)
            visible: root.jabraService && root.jabraService.batteryKnown

            PanelSectionHeader {
              width: parent.width
              text: "BATTERY"
            }

            Row {
              width: parent.width
              spacing: Style.space(12)

              Text {
                text: root.batteryText()
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                anchors.verticalCenter: parent.verticalCenter
              }

              Rectangle {
                width: parent.width - Style.space(76)
                height: Style.space(8)
                radius: height / 2
                color: root.dim
                opacity: 0.45
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                  width: parent.width * Math.max(0, Math.min(100,
                    Number(root.jabraService ? root.jabraService.battery : 0))) / 100
                  height: parent.height
                  radius: height / 2
                  color: root.jabraService && Number(root.jabraService.battery) <= 15
                    ? root.urgent : root.healthy
                }
              }
            }
          }

          Column {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              width: parent.width
              text: "CONNECTION"
            }

            DetailRow {
              label: "Bluetooth"
              value: root.connected ? "Connected" : root.paired ? "Paired" : "Not paired"
            }

            DetailRow {
              visible: root.connected
              label: "Audio output"
              value: root.jabraService && root.jabraService.activeOutput ? "Active" : "Available"
            }

            Row {
              spacing: Style.spacing.md

              ActionButton {
                text: root.connected ? "DISCONNECT" : "CONNECT"
                enabled: root.paired && !root.busy
                onClicked: {
                  if (root.connected) root.jabraService.disconnectDevice()
                  else root.jabraService.connectDevice()
                }
              }

              ActionButton {
                visible: root.connected && root.jabraService && !root.jabraService.activeOutput
                text: "USE FOR AUDIO"
                enabled: root.jabraService && root.jabraService.canControlAudio && !root.busy
                onClicked: root.jabraService.activateOutput()
              }

              ActionButton {
                text: "REFRESH"
                enabled: !root.busy
                onClicked: root.jabraService.refresh()
              }
            }
          }

          Column {
            width: parent.width
            spacing: Style.space(8)
            visible: root.connected

            PanelSectionHeader {
              width: parent.width
              text: "AUDIO PROFILE"
            }

            Row {
              spacing: Style.spacing.md

              ActionButton {
                text: "MUSIC"
                selected: root.jabraService && root.jabraService.profileMode === "music"
                enabled: root.jabraService && root.jabraService.profiles.music !== null && !root.busy
                onClicked: root.jabraService.selectProfile("music")
              }

              ActionButton {
                text: "CALLS"
                selected: root.jabraService && root.jabraService.profileMode === "calls"
                enabled: root.jabraService && root.jabraService.profiles.calls !== null && !root.busy
                onClicked: root.jabraService.selectProfile("calls")
              }
            }

            DetailRow { label: "Current"; value: root.profileLabel() }
            DetailRow {
              label: "Microphone"
              value: root.jabraService && root.jabraService.microphoneAvailable
                ? "Jabra microphone" : "Unavailable in Music mode"
            }

            Text {
              width: parent.width
              text: root.jabraService && root.jabraService.profileMode === "calls"
                ? "Calls enables the microphone with lower-bandwidth mono audio."
                : "Music uses high-quality stereo playback. Switch to Calls only when an app needs the Jabra microphone."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          Column {
            width: parent.width
            spacing: Style.space(8)
            visible: root.connected && root.jabraService && root.jabraService.canControlAudio

            PanelSectionHeader {
              width: parent.width
              text: "VOLUME"
            }

            Row {
              spacing: Style.spacing.md

              ActionButton {
                text: "−"
                enabled: !root.busy
                onClicked: root.jabraService.adjustVolume(-5)
              }

              Text {
                width: Style.space(72)
                text: !root.jabraService || root.jabraService.volume === null
                  ? "—" : Number(root.jabraService.volume) + "%"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenter: parent.verticalCenter
              }

              ActionButton {
                text: "+"
                enabled: !root.busy
                onClicked: root.jabraService.adjustVolume(5)
              }

              ActionButton {
                text: root.jabraService && root.jabraService.muted ? "UNMUTE" : "MUTE"
                selected: root.jabraService ? root.jabraService.muted : false
                enabled: !root.busy
                onClicked: root.jabraService.toggleMute()
              }
            }
          }

          Text {
            width: parent.width
            visible: root.jabraService && (root.jabraService.actionMessage !== ""
              || root.jabraService.backendError !== "")
            text: root.jabraService
              ? (root.jabraService.actionMessage || root.jabraService.backendError) : ""
            color: root.jabraService && root.jabraService.backendError ? root.urgent : root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          Text {
            width: parent.width
            text: "M Music · C Calls · R Refresh · Tab next panel"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
          }
        }
      }
    }
  }
}
