import QtQuick

QtObject {
    id: root
    property Item referenceItem: null
    property var lastPosition: null
    function reset() { lastPosition = null }
    function moved(item, mouse) {
        if (!item || !referenceItem || !mouse) return false
        var p = item.mapToItem(referenceItem, mouse.x, mouse.y)
        var prior = lastPosition
        lastPosition = p
        return prior !== null && (Math.abs(p.x - prior.x) + Math.abs(p.y - prior.y) > 1)
    }
}
