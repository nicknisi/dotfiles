import QtQuick
import QtQuick.Effects

// Put this beside a clipped surface, or inside an unclipped one. Shadows draw
// outside the rectangle, so compact windows need Theme.shadowPadding around it.
RectangularShadow {
    required property Rectangle surface
    anchors.fill: surface
    radius: surface.radius
    color: Theme.shadowColor
    blur: Theme.shadowBlur
    visible: surface.visible
    opacity: parent === surface ? 1 : surface.opacity
    z: parent === surface ? -1 : surface.z
}
