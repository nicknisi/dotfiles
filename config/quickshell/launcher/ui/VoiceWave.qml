import QtQuick
import qs.Commons

// The query field while dictating: a string pinned at both ends, plucked by
// the microphone. Recent loudness flows in from the right, so speech travels
// across the field; while transcribing the string settles and a highlight
// runs along it.
Item {
  id: root
  property string mode: "listening"      // starting | listening | transcribing
  property real level: 0
  property var history: []
  property color accent: Color.accent
  property color foreground: Color.menu.text
  property real phase: 0
  property real smoothed: 0

  Canvas {
    id: canvas
    anchors.fill: parent
    renderStrategy: Canvas.Cooperative
    onPaint: root.draw()
  }

  Timer {
    interval: 33
    repeat: true
    running: root.visible
    onTriggered: {
      root.phase += root.mode === "transcribing" ? 0.22 : 0.16
      root.smoothed += (root.level - root.smoothed) * 0.35
      canvas.requestPaint()
    }
  }

  function sampleAt(t) {
    var h = root.history || []
    if (!h.length) return 0
    var idx = Math.min(h.length - 1, Math.max(0, Math.round(t * (h.length - 1))))
    // Light neighbourhood average keeps the string from kinking on single frames.
    var sum = 0, n = 0
    for (var i = idx - 2; i <= idx + 2; i++) { if (i >= 0 && i < h.length) { sum += h[i]; n++ } }
    return n ? sum / n : 0
  }

  function stroke(ctx, w, mid, ampScale, freq, drift, width, color) {
    ctx.beginPath()
    ctx.lineWidth = width
    ctx.strokeStyle = color
    var steps = 96
    for (var i = 0; i <= steps; i++) {
      var t = i / steps
      var env = Math.sin(Math.PI * t)
      var amp
      if (root.mode === "transcribing") amp = 0.12 + 0.05 * Math.sin(root.phase * 0.6)
      else amp = 0.05 + 0.03 * Math.sin(root.phase * 0.45) + 1.3 * root.sampleAt(t) + 0.25 * root.smoothed
      amp = Math.min(1, amp) * ampScale
      var y = mid + amp * env * (Math.sin(2 * Math.PI * freq * t + root.phase * drift) + 0.35 * Math.sin(2 * Math.PI * freq * 2.3 * t - root.phase * drift * 1.6))
      if (i === 0) ctx.moveTo(0, y); else ctx.lineTo(t * w, y)
    }
    ctx.stroke()
  }

  function draw() {
    var ctx = canvas.getContext("2d")
    var w = canvas.width, h = canvas.height, mid = h / 2
    ctx.clearRect(0, 0, w, h)
    if (w <= 0 || h <= 0) return
    var reach = h * 0.42
    var dim = Util.alpha(root.accent, 0.22)
    var soft = Util.alpha(root.accent, 0.5)
    var bright = root.mode === "transcribing" ? Util.alpha(root.accent, 0.75) : root.accent
    // A faint twin a beat behind gives the string body; the glow is a wide,
    // translucent pass under the thin bright stroke.
    root.stroke(ctx, w, mid, reach * 0.8, 2.6, -0.9, 1.2, dim)
    root.stroke(ctx, w, mid, reach, 3.1, 1, 6, dim)
    root.stroke(ctx, w, mid, reach, 3.1, 1, 1.8, bright)
    if (root.mode === "transcribing") {
      // Highlight running along the string.
      var x = ((root.phase * 0.09) % 1.2 - 0.1) * w
      var grad = ctx.createLinearGradient(x - w * 0.18, 0, x + w * 0.18, 0)
      grad.addColorStop(0, Util.alpha(root.foreground, 0))
      grad.addColorStop(0.5, Util.alpha(root.foreground, 0.9))
      grad.addColorStop(1, Util.alpha(root.foreground, 0))
      root.stroke(ctx, w, mid, reach, 3.1, 1, 2.2, grad)
    } else if (root.smoothed > 0.02) {
      root.stroke(ctx, w, mid, reach, 3.1, 1, 2.2 + 1.5 * root.smoothed, soft)
    }
  }
}
