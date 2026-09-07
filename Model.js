// Maps ModemManager's "access tech" string (e.g. "lte", "hspa", "edge") to a
// short generation label. Unrecognized non-empty values are shown as-is
// rather than hidden, since a new modem/tech pairing shouldn't go silent.
function gsmModeLabel(tech) {
  var t = String(tech || "").toLowerCase()
  if (t === "") return "--"
  if (t.indexOf("5gnr") !== -1) return "5G"
  if (t.indexOf("lte") !== -1) return "4G"
  if (t.indexOf("hspa") !== -1 || t.indexOf("umts") !== -1 || t.indexOf("hsdpa") !== -1 || t.indexOf("hsupa") !== -1) return "3G"
  if (t.indexOf("edge") !== -1 || t.indexOf("gprs") !== -1 || t.indexOf("gsm") !== -1) return "2G"
  return t.toUpperCase()
}

// Signal quality (0-100%) to a 0-5 filled-bar count for the meter widget.
function gsmSignalBars(percent) {
  var value = Number(percent)
  if (!isFinite(value) || value < 0) return 0
  return Math.max(0, Math.min(5, Math.ceil(value / 20)))
}

function formatBytes(bytes) {
  var n = Number(bytes)
  if (!isFinite(n) || n < 0) n = 0
  if (n < 1024) return Math.round(n) + " B"
  if (n < 1024 * 1024) return (n / 1024).toFixed(1) + " KB"
  if (n < 1024 * 1024 * 1024) return (n / (1024 * 1024)).toFixed(1) + " MB"
  return (n / (1024 * 1024 * 1024)).toFixed(2) + " GB"
}

function formatRate(bytesPerSec) {
  return formatBytes(bytesPerSec) + "/s"
}

function throughputState(previous, next, now) {
  var prev = previous || {}
  var sample = next || {}
  var iface = sample.iface || ""
  var rx = parseFloat(sample.rx_bytes || "0")
  var tx = parseFloat(sample.tx_bytes || "0")
  var previousTime = Number(prev.prevSampleTime || 0)

  if (iface !== (prev.prevIface || "") || previousTime === 0) {
    return {
      prevIface: iface,
      prevRxBytes: rx,
      prevTxBytes: tx,
      prevSampleTime: now,
      downloadRate: 0,
      uploadRate: 0
    }
  }

  var downloadRate = Number(prev.downloadRate || 0)
  var uploadRate = Number(prev.uploadRate || 0)
  var dt = now - previousTime
  if (dt > 0) {
    downloadRate = Math.max(0, (rx - Number(prev.prevRxBytes || 0)) / dt)
    uploadRate = Math.max(0, (tx - Number(prev.prevTxBytes || 0)) / dt)
  }

  return {
    prevIface: iface,
    prevRxBytes: rx,
    prevTxBytes: tx,
    prevSampleTime: now,
    downloadRate: downloadRate,
    uploadRate: uploadRate
  }
}

// Polls the gsm device/connection state via nmcli, plus signal quality,
// access technology, and the modem's own net interface via mmcli -- there is
// no Quickshell.Networking device type for GSM, so this is the only source
// for any of it. Always emits exactly 7 lines so the caller can split
// positionally: device state, saved connection name, signal quality percent,
// access tech, net iface, rx_bytes, tx_bytes. Any field is "" when unknown
// (no modem, no bearer up, etc.) rather than omitted, so the line count
// never shifts.
var gsmStatusScript =
  "modem=$(mmcli -L 2>/dev/null | grep -oP \"/Modem/\\K[0-9]+\" | head -1); " +
  "nmcli -t -f TYPE,STATE device status | awk -F: '$1==\"gsm\"{print $2; f=1} END{if(!f) print \"\"}'; " +
  "nmcli -t -f TYPE,NAME connection show | awk -F: '$1==\"gsm\"{print $2; exit}'; " +
  "if [ -n \"$modem\" ]; then " +
  "info=$(mmcli -m \"$modem\" 2>/dev/null); " +
  "echo \"$info\" | grep -oP \"signal quality:\\s*\\K[0-9]+\" | head -1; " +
  "echo \"$info\" | grep -oP \"access tech:\\s*\\K[a-z0-9+-]+\" | head -1; " +
  "iface=$(echo \"$info\" | grep -oP \"\\S+(?=\\s\\(net\\))\"); " +
  "echo \"$iface\"; " +
  "if [ -n \"$iface\" ] && [ -e \"/sys/class/net/$iface/statistics/rx_bytes\" ]; then " +
  "cat \"/sys/class/net/$iface/statistics/rx_bytes\"; " +
  "cat \"/sys/class/net/$iface/statistics/tx_bytes\"; " +
  "else echo \"\"; echo \"\"; fi; " +
  "else echo \"\"; echo \"\"; echo \"\"; echo \"\"; fi"

if (typeof module !== "undefined") {
  module.exports = {
    gsmModeLabel: gsmModeLabel,
    gsmSignalBars: gsmSignalBars,
    formatBytes: formatBytes,
    formatRate: formatRate,
    throughputState: throughputState,
    gsmStatusScript: gsmStatusScript
  }
}
