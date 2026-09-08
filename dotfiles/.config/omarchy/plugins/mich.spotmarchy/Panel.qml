import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Ui
import qs.Commons
import "Model.js" as Model

Panel {
  id: root

  moduleName: "mich.spotmarchy"
  ipcTarget: "mich.spotmarchy"
  // The base only wires open/close/toggle; this widget adds transport calls
  // on the same target, so it owns the whole handler.
  manageIpc: false

  // ---------------------------------------------------------------- settings
  readonly property int maxLabelWidth: Math.max(Style.space(60), Style.space(Number(setting("maxLabelWidth", 200))))
  readonly property bool showArtist: setting("showArtist", true) !== false
  readonly property bool showProgress: setting("showProgress", true) !== false
  readonly property bool hideWhenClosed: setting("hideWhenClosed", true) !== false
  readonly property string scrollAction: String(setting("scrollAction", "Previous/next track"))
  readonly property string leftClick: String(setting("leftClick", "Open panel"))
  // Left click opens the panel like every other Omarchy bar widget; the other
  // button gets play/pause. Set leftClick to "Play/pause" to swap them.
  readonly property bool panelOnLeft: leftClick !== "Play/pause"
  readonly property string accentChoice: String(setting("accent", "Spotify green"))
  readonly property bool artBackground: setting("artBackground", true) !== false
  readonly property int artIntensity: Math.round(Math.max(0, Math.min(100, Number(setting("artIntensity", 55)))))

  // ------------------------------------------------------------------- theme
  readonly property color spotifyGreen: "#1DB954"
  readonly property color accentColor: accentChoice === "Album art" ? artAccent
    : accentChoice === "Theme accent" ? Color.accent
    : accentChoice === "Bar foreground" ? barForeground
    : spotifyGreen
  // The cover's own colour, lifted until it is bright enough to read as an
  // accent. Falls back to the green until the probe answers, so nothing ever
  // flashes an unstyled colour on the first track of a session.
  readonly property color artAccent: artDominant === "" ? spotifyGreen : Model.ensureContrast(artDominant, 0.48)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  // A blurred cover raises the panel's darkest tone, which costs the muted
  // text some of the contrast the theme gave it. Pull the muted tones back
  // towards the full-strength foreground by the same measure. Blending
  // towards the foreground rather than simply lightening is what makes this
  // work on a light theme too, where the foreground is the dark one.
  readonly property real dimRecovery: backdropActive ? 0.45 : 0
  readonly property color dim: mixToward(Qt.darker(foreground, 1.35), foreground, dimRecovery)
  readonly property color dimmer: mixToward(Qt.darker(foreground, 1.7), foreground, dimRecovery)

  function mixToward(from, to, amount) {
    if (amount <= 0) return from
    return Qt.rgba(from.r + (to.r - from.r) * amount,
                   from.g + (to.g - from.g) * amount,
                   from.b + (to.b - from.b) * amount,
                   from.a)
  }
  readonly property bool vertical: bar ? bar.vertical : false
  readonly property int barSize: bar ? bar.barSize : Style.bar.sizeHorizontal

  // ------------------------------------------------------------------ player
  readonly property var players: Mpris.players ? Mpris.players.values : []
  readonly property var player: Model.findSpotify(players)
  readonly property bool live: player !== null && player !== undefined
  readonly property bool playing: live && player.isPlaying === true

  readonly property string trackTitle: live ? String(player.trackTitle || "") : ""
  readonly property string trackArtist: live ? String(player.trackArtist || "") : ""
  readonly property string trackAlbum: live ? String(player.trackAlbum || "") : ""
  readonly property string artUrl: live ? String(player.trackArtUrl || "") : ""
  readonly property string label: Model.barLabel(player, showArtist)

  readonly property real trackLength: live && player.lengthSupported ? Math.max(0, player.length) : 0
  // Quickshell keeps extrapolating position between polls, so it can overshoot
  // the track length by a fraction of a second right before a track change.
  readonly property real trackPosition: {
    if (!live || !player.positionSupported) return 0
    var pos = Math.max(0, player.position)
    return trackLength > 0 ? Math.min(pos, trackLength) : pos
  }
  readonly property real progress: trackLength > 0 ? Math.max(0, Math.min(1, trackPosition / trackLength)) : 0

  readonly property bool canSeek: live && player.canSeek && trackLength > 0
  readonly property bool shuffleOn: live && player.shuffleSupported && player.shuffle === true
  readonly property int loopState: live && player.loopSupported ? player.loopState : MprisLoopState.None
  readonly property string loopIcon: loopState === MprisLoopState.Track ? "󰑘"
    : loopState === MprisLoopState.Playlist ? "󰑖"
    : "󰑗"
  readonly property string loopName: loopState === MprisLoopState.Track ? "track"
    : loopState === MprisLoopState.Playlist ? "playlist"
    : "off"

  readonly property bool shown: live || !hideWhenClosed


  // ------------------------------------------------------------ album colour
  //
  // The panel wears the cover as its background, and "adaptive" is the whole
  // point: a scrim strong enough for a Daft Punk sleeve of near-white beige
  // would bury a dark one, so the cover is measured and the scrim answers.
  // Two numbers come back — the mean luminance, which sets how hard the scrim
  // has to work, and the dominant colour, which tints it so the panel reads
  // as part of the artwork instead of a window parked on top of it.
  //
  // Qt can show the image but cannot tell us what colour it is, so an
  // ImageMagick probe does the reading. Everything downstream falls back to
  // the plain theme panel while that is unanswered or has failed, which is
  // also what happens on a machine with no ImageMagick at all.
  property string artDominant: ""
  property string artMean: ""
  property real artLuma: 0
  // The URL the three values above describe — not necessarily the current
  // one, which is what stops a stale answer from repainting a new track.
  property string artProbed: ""
  property string artProbeError: ""
  // The normalised copy the probe wrote. Everything the panel displays comes
  // from here and never from `artUrl`: a QML Image handed a raw art URL would
  // repeat none of the probe's checks, and Qt would fetch any origin, follow
  // redirects, and decode whatever its image plugins handle -- SVG and PDF
  // included -- inside the shell process.
  property string artFile: ""
  readonly property string artSourceUrl: Model.fileUrl(artFile)

  // Once the displayed cover comes from the probe, there is no configuration
  // in which it is skippable -- turning the backdrop off still leaves the
  // panel's own thumbnail to produce.
  readonly property bool artWanted: true
  // Only true once a cover has actually been measured and drawn.
  readonly property bool backdropActive: artBackground && artFile !== "" && artProbed === artUrl
  readonly property real scrimStrength: Model.scrimAlpha(artLuma, artIntensity)
  readonly property real artBrightness: Model.artBrightness(artLuma)

  // Theme panel colour pushed a fifth of the way towards the cover, at
  // whatever opacity the cover's brightness demands. Tinting the theme colour
  // rather than replacing it is what keeps a dark theme dark and a light one
  // light while still letting the album through.
  readonly property color scrimColor: {
    var base = Color.popups.background
    if (artDominant === "" || !artBackground) return Qt.rgba(base.r, base.g, base.b, artBackground ? scrimStrength : 1.0)
    var dominant = Qt.color(artDominant)
    var mixed = Qt.tint(base, Qt.rgba(dominant.r, dominant.g, dominant.b, 0.20))
    return Qt.rgba(mixed.r, mixed.g, mixed.b, scrimStrength)
  }

  onArtUrlChanged: artProbeDelay.restart()
  onArtWantedChanged: if (artWanted) probeArt(false)
  Component.onCompleted: probeArt(false)

  function probeArt(force) {
    if (!artWanted) return

    var target = Model.artProbeTarget(root.artUrl)
    if (!target) {
      root.forgetArt()
      return
    }
    if (!force && root.artProbed === root.artUrl) return

    // A skipped-through queue can outrun the probe; the last URL wins.
    if (artProbe.running) artProbe.running = false
    artProbe.pending = root.artUrl
    artProbe.command = ["/bin/sh", "-c", Model.artProbeScript(), "sh", target]
    artProbe.running = true
  }

  function forgetArt() {
    root.artFile = ""
    root.artDominant = ""
    root.artMean = ""
    root.artLuma = 0
    root.artProbed = ""
  }

  function applyArtProbe(url, text) {
    // A probe that finished after the track already moved on describes the
    // wrong cover, so drop it and let the newer one land.
    if (url !== root.artUrl) return

    var probe = Model.parseArtProbe(text)
    if (!probe) {
      root.artProbeError = "no colour in probe output"
      return
    }

    root.artProbeError = ""
    root.artFile = probe.file
    root.artDominant = probe.dominant
    root.artMean = probe.mean
    root.artLuma = probe.luma
    root.artProbed = url
  }

  // Track changes arrive in bursts while skipping; only the settled one is
  // worth a subprocess and a download.
  Timer {
    id: artProbeDelay
    interval: 250
    onTriggered: root.probeArt(false)
  }

  Process {
    id: artProbe
    property string pending: ""

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyArtProbe(artProbe.pending, text)
    }

    onExited: function(exitCode) {
      // The collector still fires on failure, with nothing in it; this is
      // only here so the reason survives for `artDebug`.
      if (exitCode !== 0) root.artProbeError = "probe exited " + exitCode
    }
  }


  // ----------------------------------------------------------------- actions
  function playPause() {
    if (!live) {
      launch()
      return false
    }
    if (player.canTogglePlaying) {
      player.togglePlaying()
      return true
    }
    if (playing && player.canPause) {
      player.pause()
      return true
    }
    if (!playing && player.canPlay) {
      player.play()
      return true
    }
    return false
  }

  function skipNext() {
    if (!live || !player.canGoNext) return false
    player.next()
    return true
  }

  function skipPrevious() {
    if (!live || !player.canGoPrevious) return false
    player.previous()
    return true
  }

  function seekTo(seconds) {
    if (!canSeek) return false
    player.position = Math.max(0, Math.min(trackLength, seconds))
    return true
  }

  function nudgeVolume(delta) {
    if (!live || !player.volumeSupported) return false
    player.volume = Math.max(0, Math.min(1, player.volume + delta))
    return true
  }

  function toggleShuffle() {
    if (!live || !player.shuffleSupported) return false
    player.shuffle = !player.shuffle
    return true
  }

  function cycleLoop() {
    if (!live || !player.loopSupported) return false
    player.loopState = loopState === MprisLoopState.None ? MprisLoopState.Playlist
      : loopState === MprisLoopState.Playlist ? MprisLoopState.Track
      : MprisLoopState.None
    return true
  }

  // Focuses the running window, launches the app, or offers the installer —
  // whichever applies. Cheaper to defer to Omarchy than to reimplement.
  function launch() {
    if (bar) bar.run("omarchy launch spotify")
  }

  function statusJson() {
    return JSON.stringify({
      running: root.live,
      playing: root.playing,
      title: root.trackTitle,
      artist: root.trackArtist,
      album: root.trackAlbum,
      artUrl: root.artUrl,
      position: root.trackPosition,
      length: root.trackLength,
      shuffle: root.shuffleOn,
      loop: root.loopName,
      leftClick: root.leftClick,
      artDominant: root.artDominant,
      artLuma: root.artLuma,
      revision: 5
    })
  }

  // ---------------------------------------------------------------- bar entry
  visible: shown
  readonly property real labelSlot: labelClip.visible ? labelClip.width + Style.space(6) : 0
  implicitWidth: !shown ? 0 : (vertical ? barSize : Math.round(glyph.implicitWidth + labelSlot + Style.space(12)))
  implicitHeight: !shown ? 0 : (vertical ? Math.round(glyph.implicitHeight + Style.space(10)) : barSize)

  Row {
    id: content
    anchors.centerIn: parent
    spacing: root.vertical || root.label === "" ? 0 : Style.space(6)

    Text {
      id: glyph
      anchors.verticalCenter: parent.verticalCenter
      text: ""
      color: !root.live ? Qt.darker(root.barForeground, 1.9)
        : root.playing ? root.accentColor
        : Qt.darker(root.accentColor, 1.5)
      font.family: root.fontFamily
      font.pixelSize: Style.font.body

      Behavior on color {
        enabled: !root.bar || root.bar.foregroundAnimationEnabled
        ColorAnimation { duration: 160 }
      }
    }

    Item {
      id: labelClip
      visible: !root.vertical && root.label !== ""
      width: visible ? Math.min(root.maxLabelWidth, labelText.implicitWidth) : 0
      height: glyph.height
      clip: true
      anchors.verticalCenter: parent.verticalCenter

      // The title sits at the start and stays readable. Only a title too long
      // for the slot pans, and it rests at both ends before turning around,
      // so glancing at the bar always catches the beginning of a track.
      Text {
        id: labelText
        text: root.label
        color: root.barForeground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        anchors.verticalCenter: parent.verticalCenter
        x: -panOffset

        property real panOffset: 0
        readonly property real overflow: Math.max(0, implicitWidth - labelClip.width)

        onTextChanged: {
          panOffset = 0
          if (marquee.running) marquee.restart()
        }
      }

      SequentialAnimation {
        id: marquee
        running: labelText.overflow > 0 && labelClip.visible && !root.opened
        loops: Animation.Infinite
        onRunningChanged: if (!running) labelText.panOffset = 0

        PauseAnimation { duration: 2600 }
        NumberAnimation {
          target: labelText
          property: "panOffset"
          from: 0
          to: labelText.overflow
          duration: Math.max(1600, labelText.overflow * 45)
          easing.type: Easing.InOutQuad
        }
        PauseAnimation { duration: 2200 }
        NumberAnimation {
          target: labelText
          property: "panOffset"
          from: labelText.overflow
          to: 0
          duration: Math.max(900, labelText.overflow * 20)
          easing.type: Easing.InOutQuad
        }
      }
    }
  }

  // Thin now-playing underline along the bottom of the widget.
  Rectangle {
    id: progressLine
    visible: root.showProgress && root.live && root.trackLength > 0 && !root.vertical
    x: Style.space(6)
    width: Math.max(0, (root.width - Style.space(12)) * root.progress)
    height: Math.max(1, Style.space(2))
    radius: height / 2
    color: root.accentColor
    opacity: root.playing ? 0.95 : 0.5
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Style.space(2)

    Behavior on width { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 160 } }
  }

  // The bar overlays every widget slot with its own pointer handler for
  // drag-to-reorder. It forwards a left click only to a slot that exposes
  // triggerPress(), and that same check drives the pointer cursor and the
  // open-panel indicator, so the click policy has to live here rather than in
  // a MouseArea of our own. Buttons the bar does not accept still fall
  // through to the MouseArea below, which routes them back to this function.
  function triggerPress(button) {
    if (bar) bar.hideTooltip(root)

    if (button === Qt.MiddleButton) {
      if (live) skipNext()
      return
    }

    var wantsPanel = (button === Qt.LeftButton) === panelOnLeft
    if (wantsPanel) toggle()
    else if (live) playPause()
    else launch()
  }

  MouseArea {
    id: pointer
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.RightButton | Qt.MiddleButton

    // Qt::ScrollPhase, compared numerically so this does not depend on the Qt
    // namespace enum being exposed to QML.
    readonly property int phaseNone: 0
    readonly property int phaseBegin: 1
    readonly property int phaseEnd: 3
    readonly property int phaseMomentum: 4

    // A mouse reports one 120-unit notch per detent. A touchpad reports a
    // stream of small deltas for a single two-finger swipe, so the notch model
    // would skip several tracks per gesture. Track skipping is therefore
    // gesture-based: one skip per swipe, no matter how far the fingers travel.
    property real wheelAccumulator: 0
    property bool gestureSkipped: false

    // How far a swipe must travel before it counts, so resting fingers or a
    // stray brush while reaching for the bar do not change the track.
    readonly property real gestureThreshold: 50
    readonly property real notch: 120

    property var wheelTrace: []

    function recordWheel(wheel, outcome) {
      var trace = pointer.wheelTrace.slice(-11)
      trace.push({
        phase: wheel.phase,
        angle: wheel.angleDelta.y,
        pixel: wheel.pixelDelta.y,
        accumulated: Math.round(pointer.wheelAccumulator),
        outcome: outcome
      })
      pointer.wheelTrace = trace
    }

    function endGesture() {
      pointer.wheelAccumulator = 0
      pointer.gestureSkipped = false
    }

    onClicked: function(mouse) { root.triggerPress(mouse.button) }

    onWheel: function(wheel) {
      if (!root.live || root.scrollAction === "Nothing") {
        pointer.recordWheel(wheel, "ignored")
        return
      }

      // Kinetic scrolling after the fingers lift is not a deliberate request.
      if (wheel.phase === pointer.phaseMomentum) {
        pointer.recordWheel(wheel, "momentum")
        return
      }

      if (wheel.phase === pointer.phaseBegin) pointer.endGesture()
      if (wheel.phase === pointer.phaseEnd) {
        pointer.recordWheel(wheel, "gesture-end")
        pointer.endGesture()
        return
      }

      // A touchpad sets a scroll phase or reports pixel deltas; a mouse wheel
      // arrives as bare 120-unit steps. Some drivers report neither phase nor
      // pixels, so a sub-notch delta is treated as continuous scrolling too.
      var continuous = wheel.phase !== pointer.phaseNone
        || wheel.pixelDelta.y !== 0
        || Math.abs(wheel.angleDelta.y) < pointer.notch

      pointer.wheelAccumulator += wheel.angleDelta.y
      // The gesture is over once the events stop, which is the only end signal
      // available when the driver reports no phase.
      gestureIdle.restart()

      if (root.scrollAction === "Volume") {
        // Volume is meant to be continuous, so every step counts on both kinds
        // of device — just scaled so a swipe is not a jump to the extremes.
        var volumeStep = continuous ? pointer.notch * 2 : pointer.notch
        while (Math.abs(pointer.wheelAccumulator) >= volumeStep) {
          var volumeUp = pointer.wheelAccumulator > 0
          pointer.wheelAccumulator += volumeUp ? -volumeStep : volumeStep
          root.nudgeVolume(volumeUp ? 0.05 : -0.05)
        }
        pointer.recordWheel(wheel, "volume")
        return
      }

      if (continuous) {
        if (pointer.gestureSkipped || Math.abs(pointer.wheelAccumulator) < pointer.gestureThreshold) {
          pointer.recordWheel(wheel, pointer.gestureSkipped ? "gesture-consumed" : "accumulating")
          return
        }

        pointer.gestureSkipped = true
        var swipeUp = pointer.wheelAccumulator > 0
        pointer.recordWheel(wheel, swipeUp ? "previous" : "next")
        if (swipeUp) root.skipPrevious()
        else root.skipNext()
        return
      }

      // Discrete wheel: one skip per notch, rate limited so a fast spin does
      // not tear through the queue.
      if (Math.abs(pointer.wheelAccumulator) < pointer.notch) {
        pointer.recordWheel(wheel, "accumulating")
        return
      }

      var up = pointer.wheelAccumulator > 0
      pointer.wheelAccumulator = 0

      if (skipCooldown.running) {
        pointer.recordWheel(wheel, "cooldown")
        return
      }

      skipCooldown.restart()
      pointer.recordWheel(wheel, up ? "previous" : "next")
      if (up) root.skipPrevious()
      else root.skipNext()
    }

    onEntered: if (root.bar) root.bar.showTooltip(root, Model.tooltipText(root.player))
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  Timer {
    id: gestureIdle
    interval: 220
    repeat: false
    onTriggered: pointer.endGesture()
  }

  Timer {
    id: skipCooldown
    interval: 350
    repeat: false
  }

  // MPRIS position is only re-read when something asks for it, so drive a
  // re-read while there is a progress display that would otherwise go stale.
  Timer {
    running: root.playing && (root.opened || progressLine.visible)
    interval: root.opened ? 500 : 1000
    repeat: true
    onTriggered: if (root.player) root.player.positionChanged()
  }

  // ------------------------------------------------------------------ popup
  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.opened
    contentWidth: popup.fittedContentWidth(Style.space(340))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    // The cover as the panel's own background. It bleeds out over the card's
    // padding so the artwork reaches the edges, but stops at the border, so
    // the theme still draws the frame and the panel keeps its outline.
    Item {
      id: backdrop
      z: -1
      anchors.fill: parent
      anchors.topMargin: -popup.padding
      anchors.bottomMargin: -popup.padding
      anchors.leftMargin: -popup.padding
      anchors.rightMargin: -popup.padding
      visible: root.artBackground

      // The card is rounded outside its border; inside it, the corner is
      // that much tighter. Zero on a theme with square corners, which is
      // also where the mask below turns itself off.
      readonly property real corner: Math.max(0, Style.cornerRadius - Border.top(popup.borderSpec))

      // Blurring samples past the edges of its source, so an image stopping
      // at the card would fade to nothing around the rim. The cover is drawn
      // larger than the card instead and the mask below cuts it back, which
      // puts the fade safely outside.
      readonly property real bleed: Style.space(32)

      Image {
        id: artSource
        anchors.fill: parent
        anchors.margins: -backdrop.bleed
        source: root.artBackground ? root.artSourceUrl : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        // Drawn only through the effect below, never directly.
        visible: false
        // A fixed decode size, not one bound to the item's own width, which
        // would re-decode the image every time the popup resizes. The blur
        // erases anything finer than this long before it reaches the screen.
        sourceSize.width: 384
        sourceSize.height: 384
      }

      // Blurred hard, desaturated a little, and dimmed by however bright the
      // cover measured. The blur is what turns a photograph into a texture:
      // no edge in it competes with the text sitting on top.
      MultiEffect {
        anchors.fill: artSource
        source: artSource
        blurEnabled: true
        blur: 1.0
        blurMax: 48
        blurMultiplier: 1.6
        saturation: 0.2
        // Flattening the cover's own contrast a little is worth more to the
        // text on top than it costs the artwork underneath: it is the bright
        // patches, not the average, that swallow a caption.
        contrast: -0.1
        brightness: root.artBrightness
        maskEnabled: true
        maskSource: cornerMask
        // Without a threshold the mask's transparent margin still passes, and
        // the blur spills out over the card's border.
        maskThresholdMin: 0.5
        maskSpreadAtMin: 0.05
        // Fades out while the next cover loads and back in when it is ready,
        // so a track change is a crossfade rather than a flash of theme.
        opacity: artSource.status === Image.Ready ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
          NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
        }
      }

      // Matches the effect's geometry exactly, and marks the card-sized
      // rectangle inside it as the only part that survives.
      Item {
        id: cornerMask
        anchors.fill: artSource
        layer.enabled: true
        visible: false

        Rectangle {
          anchors.fill: parent
          anchors.margins: backdrop.bleed
          radius: backdrop.corner
          color: "black"
        }
      }

      // The legibility scrim, and the adaptive half of this whole feature:
      // theme panel colour, tinted towards the cover, at the opacity the
      // cover's brightness calls for. Text contrast stays where the theme
      // put it no matter what is playing.
      Rectangle {
        anchors.fill: parent
        radius: backdrop.corner
        color: root.scrimColor

        Behavior on color {
          ColorAnimation { duration: 280; easing.type: Easing.OutCubic }
        }
      }
    }

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(12)

      Row {
        width: parent.width
        spacing: Style.space(12)

        BorderSurface {
          id: art
          width: Style.space(72)
          height: Style.space(72)
          radius: Style.spacing.labelGap
          color: Style.normalFillFor(root.foreground, root.accentColor)
          borderSpec: Border.controlSpec("normal", root.foreground, root.accentColor)

          Image {
            anchors.fill: parent
            anchors.margins: Style.space(2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            source: root.artSourceUrl
            visible: status === Image.Ready
          }

          Text {
            anchors.centerIn: parent
            visible: root.artSourceUrl === ""
            text: ""
            color: root.accentColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
          }
        }

        Column {
          width: parent.width - art.width - Style.space(12)
          spacing: Style.space(3)
          anchors.verticalCenter: parent.verticalCenter

          Text {
            width: parent.width
            text: root.live ? (root.trackTitle || "Nothing playing") : "Spotify is not running"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
            elide: Text.ElideRight
          }

          Text {
            width: parent.width
            text: root.trackArtist
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
            visible: text !== ""
          }

          Text {
            width: parent.width
            text: root.trackAlbum
            color: root.dimmer
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            visible: text !== ""
          }
        }
      }

      Column {
        width: parent.width
        spacing: Style.space(1)
        visible: root.live && root.trackLength > 0

        PanelSlider {
          id: seekSlider
          width: parent.width
          bar: root.bar
          minimum: 0
          maximum: Math.max(1, root.trackLength)
          value: root.trackPosition
          step: 5
          fillColor: root.accentColor
          knobColor: root.accentColor
          enabled: root.canSeek
          opacity: root.canSeek ? 1.0 : 0.5
          onReleased: function(value) { root.seekTo(value) }
        }

        Item {
          width: parent.width
          height: elapsedText.implicitHeight

          Text {
            id: elapsedText
            anchors.left: parent.left
            text: Model.formatTime(seekSlider.dragging ? seekSlider.liveValue : root.trackPosition)
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Text {
            anchors.right: parent.right
            text: Model.formatTime(root.trackLength)
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(4)
        visible: root.live

        Button {
          iconText: "󰒝"
          foreground: root.foreground
          accent: root.accentColor
          selected: root.shuffleOn
          tooltipText: root.shuffleOn ? "Shuffle on" : "Shuffle off"
          enabled: root.live && root.player.shuffleSupported
          opacity: enabled ? (root.shuffleOn ? 1.0 : 0.6) : 0.3
          onClicked: root.toggleShuffle()
        }

        Button {
          iconText: "󰒮"
          foreground: root.foreground
          accent: root.accentColor
          horizontalPadding: Style.spacing.controlPaddingX
          enabled: root.live && root.player.canGoPrevious
          opacity: enabled ? 1.0 : 0.4
          onClicked: root.skipPrevious()
        }

        Button {
          iconText: root.playing ? "󰏤" : "󰐊"
          foreground: root.accentColor
          accent: root.accentColor
          iconSize: Style.font.iconLarge
          horizontalPadding: Style.spacing.panelGap
          enabled: root.live
          opacity: enabled ? 1.0 : 0.4
          onClicked: root.playPause()
        }

        Button {
          iconText: "󰒭"
          foreground: root.foreground
          accent: root.accentColor
          horizontalPadding: Style.spacing.controlPaddingX
          enabled: root.live && root.player.canGoNext
          opacity: enabled ? 1.0 : 0.4
          onClicked: root.skipNext()
        }

        Button {
          iconText: root.loopIcon
          foreground: root.foreground
          accent: root.accentColor
          selected: root.loopState !== MprisLoopState.None
          tooltipText: "Repeat: " + root.loopName
          enabled: root.live && root.player.loopSupported
          opacity: enabled ? (root.loopState !== MprisLoopState.None ? 1.0 : 0.6) : 0.3
          onClicked: root.cycleLoop()
        }
      }

      Row {
        width: parent.width
        spacing: Style.space(8)
        visible: root.live && root.player.volumeSupported

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.live && root.player.volume < 0.01 ? "󰝟" : "󰕾"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          width: Style.space(20)
          horizontalAlignment: Text.AlignHCenter
        }

        PanelSlider {
          width: parent.width - Style.space(28)
          anchors.verticalCenter: parent.verticalCenter
          bar: root.bar
          minimum: 0
          maximum: 1
          step: 0.05
          value: root.live ? root.player.volume : 0
          fillColor: root.accentColor
          knobColor: root.accentColor
          onMoved: function(value) { if (root.live) root.player.volume = value }
        }
      }

      PanelSeparator { foreground: root.foreground }

      Button {
        width: parent.width
        text: root.live ? "Show Spotify" : "Launch Spotify"
        iconText: ""
        foreground: root.foreground
        accent: root.accentColor
        bordered: true
        onClicked: {
          root.launch()
          root.close()
        }
      }
    }
  }

  IpcHandler {
    target: "mich.spotmarchy"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function playPause(): string { return root.playPause() ? "ok" : "unhandled" }
    function next(): string { return root.skipNext() ? "ok" : "unhandled" }
    function previous(): string { return root.skipPrevious() ? "ok" : "unhandled" }
    function shuffle(): string { return root.toggleShuffle() ? "ok" : "unhandled" }
    function loop(): string { return root.cycleLoop() ? "ok" : "unhandled" }
    function launch(): void { root.launch() }
    function status(): string { return root.statusJson() }
    function wheelDebug(): string { return JSON.stringify(pointer.wheelTrace) }
    function artDebug(): string {
      return JSON.stringify({
        wanted: root.artWanted,
        file: root.artFile,
        url: root.artUrl,
        target: Model.artProbeTarget(root.artUrl),
        probed: root.artProbed,
        running: artProbe.running,
        error: root.artProbeError,
        mean: root.artMean,
        dominant: root.artDominant,
        luma: root.artLuma,
        scrim: root.scrimStrength,
        brightness: root.artBrightness,
        imageStatus: artSource.status
      })
    }
    function reprobeArt(): void { root.probeArt(true) }
  }
}
