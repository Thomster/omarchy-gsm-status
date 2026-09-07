import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Networking
import qs.Ui
import qs.Commons
import "Model.js" as Model

Panel {
  id: root
  moduleName: "gsm-status"
  ipcTarget: "gsm-status"
  // The bar host sizes each widget's slot from this. It only picks up the
  // value once, early -- it does not re-flow the slot if implicitWidth
  // changes later (which it otherwise would, since gsmDevicePresent starts
  // false until the first async nmcli/mmcli poll resolves a few seconds
  // after load). So this stays unconditional rather than collapsing to 0
  // when no modem is present -- the widget is opt-in via shell.json anyway
  // (disable it there, or with `omarchy plugin disable gsm-status`, if you
  // don't have a modem), matching how every other bar icon on this shell
  // works.
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // GSM has no Quickshell.Networking device type, so its state is polled
  // straight from nmcli/mmcli. gsmDeviceState mirrors `nmcli device status`'s
  // STATE column for the gsm device ("connected" | "connecting" |
  // "disconnected" | "unavailable" | "" when no gsm device exists at all).
  property string gsmDeviceState: ""
  property string gsmConnectionName: ""
  property bool gsmBusy: false
  // Arms a beat after the panel opens, so a stray click delivered by the open
  // gesture itself can't be read as the user flipping the toggle.
  property bool gsmToggleArmed: false
  readonly property bool gsmDevicePresent: gsmDeviceState !== ""
  readonly property bool gsmConnected: gsmDeviceState === "connected"
  readonly property bool canToggleGsm: gsmDevicePresent && gsmConnectionName !== ""
  readonly property string gsmToggleHint: gsmConnected ? "Turn mobile data off" : "Turn mobile data on"

  // GSM is the lowest-priority interface: it defers to Wi-Fi (and, via the
  // separate omarchy-network-priority service if installed, to Ethernet).
  // This is a continuously held invariant, not a one-shot reaction, for the
  // same reason the Ethernet rule is: GSM connection profiles are typically
  // autoconnect=yes, so ModemManager/NetworkManager can bring GSM back up on
  // its own with nothing else changing. Watching Wi-Fi's live radio state and
  // GSM's own polled state, rather than a derived summary, means either one
  // flipping on re-triggers this. Self-contained: doesn't require
  // network-priority to be installed, and composes fine if it is (Ethernet
  // going up there already drops Wi-Fi, which in turn drops GSM here).
  readonly property bool wifiRadioOn: Networking.wifiEnabled

  function enforceWifiOverGsm() {
    if (wifiRadioOn && gsmConnected) toggleGsm()
  }

  onWifiRadioOnChanged: enforceWifiOverGsm()
  onGsmConnectedChanged: enforceWifiOverGsm()

  property real gsmSignalPercent: -1
  property string gsmAccessTech: ""
  property string gsmDataIface: ""
  property real gsmPrevRxBytes: 0
  property real gsmPrevTxBytes: 0
  property real gsmPrevSampleTime: 0
  property string gsmPrevIface: ""
  property real gsmDownloadRate: 0
  property real gsmUploadRate: 0
  readonly property int gsmSignalBars: Model.gsmSignalBars(gsmSignalPercent)
  readonly property string gsmModeLabel: Model.gsmModeLabel(gsmAccessTech)

  // Bar icon only shows once a modem is actually present -- there's nothing
  // to control or report on otherwise.
  readonly property string icon: "󱄙"

  function refreshGsmStatus() {
    if (gsmStatusProc.running) return
    gsmStatusProc.running = true
  }

  function updateGsmStatus(raw) {
    var lines = String(raw || "").split("\n")
    root.gsmDeviceState = lines[0] || ""
    root.gsmConnectionName = lines[1] || ""
    root.gsmSignalPercent = lines[2] ? parseFloat(lines[2]) : -1
    root.gsmAccessTech = lines[3] || ""
    root.gsmDataIface = lines[4] || ""

    var state = Model.throughputState({
      prevIface: gsmPrevIface,
      prevRxBytes: gsmPrevRxBytes,
      prevTxBytes: gsmPrevTxBytes,
      prevSampleTime: gsmPrevSampleTime,
      downloadRate: gsmDownloadRate,
      uploadRate: gsmUploadRate
    }, { iface: root.gsmDataIface, rx_bytes: lines[5] || "0", tx_bytes: lines[6] || "0" }, Date.now() / 1000)

    gsmPrevIface = state.prevIface
    gsmPrevRxBytes = state.prevRxBytes
    gsmPrevTxBytes = state.prevTxBytes
    gsmPrevSampleTime = state.prevSampleTime
    gsmDownloadRate = state.downloadRate
    gsmUploadRate = state.uploadRate
  }

  function toggleGsm() {
    if (!canToggleGsm || gsmActionProc.running) return
    var enabling = !gsmConnected
    gsmBusy = true
    gsmActionProc.command = ["nmcli", "connection", enabling ? "up" : "down", gsmConnectionName]
    gsmActionProc.running = true
  }

  function formatRate(bytesPerSec) { return Model.formatRate(bytesPerSec) }

  onOpenedChanged: {
    if (opened) {
      refreshGsmStatus()
      gsmToggleArmed = false
      gsmToggleArmTimer.restart()
    } else {
      gsmToggleArmTimer.stop()
      gsmToggleArmed = false
    }
  }

  Process {
    id: gsmStatusProc
    command: ["bash", "-c", Model.gsmStatusScript]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateGsmStatus(text)
    }
  }

  // Unlike a live NetworkManager service binding, gsmConnected only ever
  // updates when this poll runs. It stays running even with the panel
  // closed (just slower) so the bar icon and any other consumer of this
  // state stay reasonably current.
  Timer {
    id: gsmPoll
    interval: root.opened ? 2000 : 10000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refreshGsmStatus()
  }

  Timer {
    id: gsmToggleArmTimer
    interval: 300
    repeat: false
    onTriggered: root.gsmToggleArmed = true
  }

  // Separate from any other action runner: a GSM connect/disconnect can take
  // a while (modem registration).
  Process {
    id: gsmActionProc
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
    onExited: function(exitCode) {
      gsmBusy = false
      root.refreshGsmStatus()
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.icon
    // Always visible (see the implicitWidth comment above for why) -- dimmed
    // rather than hidden when no modem is present, so an install on a
    // machine without one reads as "no modem" instead of an unexplained gap.
    opacity: root.gsmDevicePresent ? 1.0 : 0.35

    onPressed: function(b) {
      if (root.opened) root.close()
      else root.open()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(260))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
    }

    Column {
      id: column
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      spacing: Style.space(12)

      PanelSectionHeader {
        text: "MOBILE DATA"
        foreground: root.bar.foreground
        fontFamily: root.bar.fontFamily
      }

      GridLayout {
        width: parent.width
        columns: 4
        columnSpacing: Style.space(20)
        rowSpacing: Style.spacing.labelGap

        InfoLabel { text: "Signal"; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily }
        SignalBars { filled: root.gsmSignalBars; foreground: root.bar.foreground }
        InfoLabel { text: "Mode"; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily }
        DetailValue { text: root.gsmModeLabel; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily }

        InfoLabel { text: "TX Rate"; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily }
        DetailValue {
          text: root.gsmConnected ? root.formatRate(root.gsmUploadRate) : "--"
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
        }
      }

      RowLayout {
        width: parent.width

        Text {
          text: "Mobile Data"
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.body
          Layout.fillWidth: true
        }

        ToggleSwitch {
          id: gsmSwitch
          checked: root.gsmConnected
          busy: root.gsmBusy
          foreground: root.bar.foreground
          onToggled: if (root.gsmToggleArmed) root.toggleGsm()

          PanelToolTip {
            visible: gsmSwitch.containsMouse
            text: root.gsmToggleHint
            fontFamily: root.bar.fontFamily
          }
        }
      }
    }
  }
}
