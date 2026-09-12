import QtQuick
import qs.Commons

// Right-hand detail for the selected row: label, swatch, text or image, hint.
Item {
  id: root
  property var row: ({})
  property bool compact: true
  property color accent: Color.accent
  property color foreground: Color.menu.text
  readonly property bool clipboard: (row.previewLabel || "") === "CLIPBOARD" || (row.previewLabel || "") === "DICTATION"
  readonly property bool emoji: row.emoji === true
  readonly property string imagePath: String(row.previewImage || "")
  readonly property bool image: imagePath !== ""
  readonly property bool vector: /\.svgz?$/i.test(imagePath)
  readonly property real dpr: Screen.devicePixelRatio
  // With an image underneath, the caption keeps to a few lines so the picture
  // gets the room; only at the smallest size may it take a share of the pane,
  // so a long path is never cut short of its file name.
  readonly property int captionLines: 3
  readonly property real captionShare: 0.4
  readonly property var captionScale: compact ? [Style.font.display, Style.font.heading, Style.font.title, Style.font.body]
                                              : [Style.font.displayLarge, Style.font.display, Style.font.heading, Style.font.title, Style.font.body]

  // Theme font glyph and line extents per pixel of font size.
  FontMetrics { id: mono; font.family: Style.font.menuFamily; font.pixelSize: 100 }
  readonly property real glyphRatio: mono.averageCharacterWidth / 100
  readonly property real lineRatio: mono.lineSpacing / 100

  // Room the caption may take at `px` above an image, in pixels. Half a line
  // of slack keeps a caption that just fits from eliding on rounding.
  function captionBudget(px, height) {
    var lines = (root.captionLines + 0.5) * px * root.lineRatio
    return px === root.captionScale[root.captionScale.length - 1] ? Math.max(lines, height * root.captionShare) : lines
  }

  // Largest size in the scale whose wrapped caption still fits its room.
  function captionSize(text, width, height) {
    var chars = String(text || "").length
    for (var i = 0; i < root.captionScale.length; i++) {
      var px = root.captionScale[i]
      var perLine = Math.max(1, Math.floor(width / (px * root.glyphRatio)))
      var lines = Math.ceil(chars / perLine)
      var room = root.image ? root.captionBudget(px, height) : height
      if (lines * px * root.lineRatio <= room) return px
    }
    return root.captionScale[root.captionScale.length - 1]
  }

  // Scale that fits a native size into a box without enlarging it; a vector
  // with no useful native size may grow until its long side reaches `floor`.
  function fitScale(w, h, boxW, boxH, floor) {
    if (!(w > 0) || !(h > 0) || !(boxW > 0) || !(boxH > 0)) return 0
    var s = Math.min(1, boxW / w, boxH / h)
    if (floor > 0 && Math.max(w, h) * s < floor) s = Math.min(boxW / w, boxH / h, floor / Math.max(w, h))
    return s
  }

  Text {
    id: label
    x: 0; y: Style.space(10)
    text: root.row.previewLabel || "PREVIEW"
    textFormat: Text.PlainText
    font.family: Style.font.menuFamily
    font.pixelSize: Style.font.caption
    font.letterSpacing: 2
    color: Util.alpha(root.foreground, 0.5)
  }
  Rectangle {
    id: swatch
    y: Style.space(44); width: parent.width; height: Style.space(96)
    radius: Style.cornerRadius
    visible: !!root.row.swatch
    color: root.row.swatch || "transparent"
    border.width: 1
    border.color: Util.alpha(root.foreground, 0.15)
  }
  // Measure without eliding: the displayed text's implicit height can depend
  // on its clipped height, which otherwise creates a binding loop.
  Text {
    id: captionMeasure
    visible: false
    text: root.image ? caption.text : ""
    textFormat: Text.PlainText
    font: caption.font
    width: caption.width
    wrapMode: caption.wrapMode
  }
  Text {
    id: caption
    y: root.row.swatch ? swatch.y + swatch.height + Style.space(18) : Style.space(46)
    width: parent.width
    readonly property int room: parent.height - y - Style.space(66)
    height: root.image ? Math.min(captionMeasure.implicitHeight, root.captionBudget(font.pixelSize, room)) : room
    visible: !!root.row.preview
    text: root.row.preview || ""
    textFormat: Text.PlainText
    color: root.clipboard ? Util.alpha(root.foreground, 0.85) : root.accent
    font.family: root.emoji ? "Noto Color Emoji" : Style.font.menuFamily
    font.pixelSize: root.emoji ? Style.space(72) : (root.clipboard ? Style.font.body : root.captionSize(text, width, room))
    wrapMode: Text.WrapAnywhere
    elide: Text.ElideRight
  }
  // Reads a vector's declared size; rasters report theirs through `picture`.
  Image {
    id: probe
    visible: false
    source: root.vector ? Util.fileUrl(root.imagePath) : ""
    asynchronous: true
  }
  Image {
    id: picture
    readonly property real above: caption.visible ? caption.y + caption.height + Style.space(14) : Style.space(46)
    readonly property real boxWidth: root.width
    readonly property real boxHeight: hint.y - above - Style.space(14)
    readonly property real nativeWidth: root.vector ? probe.implicitWidth : implicitWidth
    readonly property real nativeHeight: root.vector ? probe.implicitHeight : implicitHeight
    readonly property real fit: root.fitScale(nativeWidth, nativeHeight, boxWidth, boxHeight, root.vector ? Style.space(120) : 0)
    x: 0; y: above
    width: Math.round(nativeWidth * fit)
    height: Math.round(nativeHeight * fit)
    visible: root.image && fit > 0
    source: root.image ? Util.fileUrl(root.imagePath) : ""
    // Stretch, not PreserveAspectFit: the item already has the source's
    // aspect, and the fit mode makes Qt enlarge a small raster to sourceSize.
    // A plain sourceSize only ever scales a raster down, so it decodes no
    // larger than the pane; a vector rasterises at exactly its drawn size.
    fillMode: Image.Stretch
    sourceSize.width: root.vector ? width * root.dpr : root.width * root.dpr
    sourceSize.height: root.vector ? height * root.dpr : root.height * root.dpr
    asynchronous: true
    smooth: true
  }
  Text {
    id: hint
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Style.space(16)
    width: parent.width
    text: root.row.previewDetail || (root.row.verb ? "Press return to " + String(root.row.verb).toLowerCase() : "")
    textFormat: Text.PlainText
    color: Util.alpha(root.foreground, 0.55)
    font.family: Style.font.menuFamily
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.Wrap
    maximumLineCount: 3
    elide: Text.ElideRight
  }
}
