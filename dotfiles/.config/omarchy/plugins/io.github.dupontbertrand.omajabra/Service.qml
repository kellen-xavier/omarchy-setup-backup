import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string pluginDirectory: Qt.resolvedUrl(".").toString()
    .replace(/^file:\/\//, "").replace(/\/$/, "")
  readonly property string cliPath: root.pluginDirectory + "/bin/omajabra"

  property bool adapterAvailable: false
  property bool adapterPowered: false
  property bool paired: false
  property bool connected: false
  property string address: ""
  property string deviceName: "Jabra"
  property var battery: null
  property bool audioAvailable: false
  property var sinkId: null
  property var deviceId: null
  property bool activeOutput: false
  property var volume: null
  property bool muted: false
  property string codec: ""
  property string profile: ""
  property string profileMode: ""
  property var profiles: ({ music: null, calls: null })
  property bool microphoneAvailable: false
  property string message: "Starting Omajabra…"
  property string backendError: ""
  property string actionMessage: ""
  property bool initialized: false
  property int revision: 0

  readonly property bool actionBusy: actionProcess.running
  readonly property bool batteryKnown: battery !== null
    && battery !== undefined && Number(battery) >= 0
  readonly property bool canControlAudio: connected && sinkId !== null && audioAvailable

  function resetDisconnected() {
    root.connected = false
    root.activeOutput = false
    root.sinkId = null
    root.deviceId = null
    root.volume = null
    root.muted = false
    root.codec = ""
    root.profile = ""
    root.profileMode = ""
    root.microphoneAvailable = false
  }

  function applyStatus(raw) {
    try {
      var data = JSON.parse(String(raw || ""))
      if (!data || typeof data !== "object") throw new Error("expected an object")
      root.adapterAvailable = data.adapterAvailable === true
      root.adapterPowered = data.adapterPowered === true
      root.paired = data.paired === true
      root.connected = data.connected === true
      root.address = String(data.address || "")
      root.deviceName = String(data.name || "Jabra")
      root.battery = data.battery === undefined ? null : data.battery
      root.audioAvailable = data.audioAvailable === true
      root.sinkId = data.sinkId === undefined ? null : data.sinkId
      root.deviceId = data.deviceId === undefined ? null : data.deviceId
      root.activeOutput = data.activeOutput === true
      root.volume = data.volume === undefined ? null : data.volume
      root.muted = data.muted === true
      root.codec = String(data.codec || "")
      root.profile = String(data.profile || "")
      root.profileMode = String(data.profileMode || "")
      root.profiles = data.profiles && typeof data.profiles === "object"
        ? data.profiles : ({ music: null, calls: null })
      root.microphoneAvailable = data.microphoneAvailable === true
      root.message = String(data.message || "")
      root.backendError = ""
      root.initialized = true
      root.revision++
    } catch (error) {
      root.backendError = "Omajabra returned invalid status data."
      console.warn("omajabra: cannot parse status", String(error))
    }
  }

  function refresh() {
    if (!refreshProcess.running) {
      refreshProcess.command = [root.cliPath, "status"]
      refreshProcess.running = true
    }
  }

  function runAction(arguments) {
    if (root.actionBusy || !Array.isArray(arguments) || arguments.length === 0) return
    root.actionMessage = ""
    actionProcess.command = [root.cliPath].concat(arguments)
    actionProcess.running = true
  }

  function connectDevice() { runAction(["connect"]) }
  function disconnectDevice() { runAction(["disconnect"]) }
  function activateOutput() { runAction(["activate"]) }
  function adjustVolume(delta) { runAction(["volume-step", String(delta)]) }
  function toggleMute() { runAction(["mute", "toggle"]) }
  function selectProfile(mode) { runAction(["profile", String(mode)]) }

  Process {
    id: watcher
    command: [root.cliPath, "watch", "--interval", "5"]
    running: true
    stdout: SplitParser {
      onRead: function(line) { root.applyStatus(line) }
    }
    stderr: StdioCollector { id: watcherError; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0 && watcherError.text)
        root.backendError = String(watcherError.text).trim()
      watcherRestart.restart()
    }
  }

  Timer {
    id: watcherRestart
    interval: 2000
    repeat: false
    onTriggered: watcher.running = true
  }

  Process {
    id: refreshProcess
    command: []
    running: false
    stdout: StdioCollector { id: refreshOutput; waitForEnd: true }
    stderr: StdioCollector { id: refreshError; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) root.applyStatus(refreshOutput.text)
      else if (refreshError.text) root.backendError = String(refreshError.text).trim()
    }
  }

  Process {
    id: actionProcess
    command: []
    running: false
    stdout: StdioCollector { id: actionOutput; waitForEnd: true }
    stderr: StdioCollector { id: actionError; waitForEnd: true }
    onExited: function(exitCode) {
      var detail = String(actionOutput.text || actionError.text || "").trim()
      try {
        var result = JSON.parse(detail)
        root.actionMessage = String(result.message || (exitCode === 0 ? "Done" : "Action failed"))
      } catch (error) {
        root.actionMessage = detail || (exitCode === 0 ? "Done" : "Action failed")
      }
      actionMessageTimer.restart()
      refreshAfterAction.restart()
    }
  }

  Timer {
    id: refreshAfterAction
    interval: 650
    repeat: false
    onTriggered: root.refresh()
  }

  Timer {
    id: actionMessageTimer
    interval: 3500
    repeat: false
    onTriggered: root.actionMessage = ""
  }
}
