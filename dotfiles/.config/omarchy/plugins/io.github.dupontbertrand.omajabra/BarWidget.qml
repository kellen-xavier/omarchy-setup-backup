import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root

  moduleName: "io.github.dupontbertrand.omajabra"

  readonly property var jabraService: bar && bar.shell
    ? bar.shell.serviceFor(root.moduleName)
    : null
  readonly property bool connected: jabraService ? jabraService.connected : false
  readonly property bool paired: jabraService ? jabraService.paired : false
  readonly property bool batteryKnown: jabraService ? jabraService.batteryKnown : false
  readonly property int battery: batteryKnown ? Number(jabraService.battery) : -1
  readonly property bool showBattery: setting("showBattery", true) === true
  readonly property bool hideWhenDisconnected: setting("hideWhenDisconnected", false) === true
  readonly property bool showsPercent: connected && showBattery && batteryKnown && !vertical
  readonly property color foregroundColor: bar ? bar.barForeground : Color.foreground
  readonly property color dimColor: Qt.darker(root.foregroundColor, 1.55)
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property bool opened: panelLoader.item
    ? panelLoader.item.opened === true
    : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root
  }

  function tooltip() {
    if (!jabraService || !jabraService.initialized) return "Omajabra — starting"
    var name = jabraService.deviceName || "Jabra"
    if (!connected) return name + " — " + jabraService.message
    var details = []
    if (batteryKnown) details.push(battery + "%")
    if (jabraService.codec) details.push(jabraService.codec)
    if (jabraService.profileMode) details.push(
      jabraService.profileMode === "music" ? "Music" : "Calls")
    return name + (details.length ? " — " + details.join(" · ") : "")
  }

  visible: !hideWhenDisconnected || connected
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: root.injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: root.moduleName
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void {
      if (root.jabraService) root.jabraService.refresh()
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    fixedWidth: vertical ? -1 : barContent.implicitWidth + scaledHorizontalMargin * 2
    fixedHeight: vertical ? Style.bar.iconSlot : -1
    tooltipText: root.tooltip()

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton && root.jabraService && root.connected)
        root.jabraService.activateOutput()
      else if (buttonCode === Qt.MiddleButton && root.jabraService)
        root.jabraService.refresh()
      else
        root.toggle()
    }

    Row {
      id: barContent
      anchors.centerIn: parent
      spacing: Style.space(5)

      Item {
        width: Style.bar.iconFont
        height: Style.bar.iconFont
        anchors.verticalCenter: parent.verticalCenter

        JabraIcon {
          anchors.fill: parent
          iconSize: parent.width
          color: root.connected ? root.foregroundColor : root.dimColor
        }

        Rectangle {
          width: Style.space(5)
          height: width
          radius: width / 2
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          color: root.connected ? "#59d98e" : root.dimColor
        }
      }

      Text {
        visible: root.showsPercent
        text: root.battery + "%"
        color: root.foregroundColor
        font.family: root.contentFontFamily
        font.pixelSize: Style.bar.iconFont
        renderType: Text.NativeRendering
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }
}
