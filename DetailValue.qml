import QtQuick
import QtQuick.Layouts
import qs.Commons

Text {
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family

  textFormat: Text.PlainText
  color: foreground
  font.family: fontFamily
  font.pixelSize: Style.font.bodySmall
  Layout.fillWidth: true
  horizontalAlignment: Text.AlignRight
}
