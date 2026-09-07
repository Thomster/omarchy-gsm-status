import QtQuick
import QtQuick.Layouts
import qs.Commons

// Reconstructed component: the original GSM panel this was split out of
// defined its own SignalBars inline, and that file was deleted before this
// one captured it. This is a from-scratch equivalent (5 ascending bars,
// filled left-to-right), not a byte-for-byte restoration -- if you had the
// original's exact look, this may differ cosmetically.
Row {
  id: root
  property int filled: 0
  property color foreground: Color.foreground

  Layout.fillWidth: true
  layoutDirection: Qt.LeftToRight
  spacing: Style.space(2)

  Repeater {
    model: 5

    delegate: Rectangle {
      required property int index
      width: Style.space(4)
      height: Style.space(4) + index * Style.space(3)
      anchors.bottom: parent ? parent.bottom : undefined
      radius: 1
      color: root.foreground
      opacity: index < root.filled ? 1.0 : 0.25
    }
  }
}
