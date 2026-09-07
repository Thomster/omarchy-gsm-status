import QtQuick
import qs.Commons

Text {
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family

  textFormat: Text.PlainText
  color: foreground
  opacity: 0.6
  font.family: fontFamily
  font.pixelSize: Style.font.bodySmall
}
