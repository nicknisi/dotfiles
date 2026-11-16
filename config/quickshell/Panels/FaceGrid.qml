import QtQuick
import qs
import "../lib/PickerNav.js" as PickerNav

// FaceGrid.qml - the Profile picture sheet's picker: ~/Pictures' images as
// the wallpaper picker's cards (PickerCard: padding 6, radius 16, a 1 px
// `hairline` ring idle, 2 px `accent` on `accentTint` focused), each image
// cropped to a circle as the circles it will fill, its file name under it.
//
//   PICTURES · ~/Pictures                        11 / 500, uppercase, inkDim
//   (  ) (  ) (  ) (  ) (  ) (  )                6 columns, 12 apart
//   name  name  name  name  name  name           12 / 500
//
// No images: one `raised` card, radius 14, hairline, "No images in
// ~/Pictures" (13, inkDim). Not loaded yet: "Looking in ~/Pictures…".
//
// Keys (key(event), which the sheet's frame asks first): Left and Right the
// previous and next card (wrapping), Up and Down a row (PickerNav), Home and
// End the ends, Enter chooses. A key shows the focus ring; the pointer moves
// the focus as it moves over a card (once `armed`), as in the pickers.
// chosen(path) on Enter or a click; nothing while `busy`.
//
// Leaf: QtQuick only (PickerThumb's ClippingRectangle aside, which
// tests/panels.sh stands a plain Image in for).
Item {
    id: grid

    // [{ name, path, mtime, size }], newest first (FaceModel.parseList).
    property var pictures: []
    property bool loaded: false
    property string dirLabel: "~/Pictures"
    property bool busy: false
    property int current: 0
    // The keys are in use: the current card draws its ring.
    property bool keyboard: false
    property bool pointer: false
    property bool armed: true

    readonly property int columns: 6
    readonly property real gap: 12
    readonly property real cardWidth: Math.floor((width - (columns - 1) * gap) / columns)
    readonly property real imageSize: cardWidth - 12
    readonly property real cardHeight: 6 + imageSize + 8 + 15 + 8
    readonly property int count: (grid.pictures ?? []).length
    readonly property var currentPicture: grid.pictures?.[grid.current] ?? null
    readonly property alias repeater: cards
    readonly property alias label: label

    signal chosen(string path)

    implicitHeight: label.height + 6 + (grid.count > 0 ? cardsBox.height : emptyCard.height)

    onCountChanged: grid.current = Math.max(0, Math.min(grid.current, grid.count - 1))

    function card(i) {
        return cards.itemAt(i);
    }
    function choose(i) {
        const p = grid.pictures?.[i];
        if (!p || grid.busy) return;
        grid.current = i;
        grid.chosen(p.path);
    }
    // A key from the sheet: true when the grid took it.
    function key(event): bool {
        if (grid.count === 0) return false;
        const rows = grid.pictures;
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        let to = -1;
        if (event.key === Qt.Key_Left) to = PickerNav.step(rows, "", grid.current, -1);
        else if (event.key === Qt.Key_Right) to = PickerNav.step(rows, "", grid.current, 1);
        else if (event.key === Qt.Key_Up || (ctrl && event.key === Qt.Key_K)) to = PickerNav.vertical(rows, "", grid.current, grid.columns, -1);
        else if (event.key === Qt.Key_Down || (ctrl && event.key === Qt.Key_J)) to = PickerNav.vertical(rows, "", grid.current, grid.columns, 1);
        else if (event.key === Qt.Key_Home) to = PickerNav.edge(rows, "", false);
        else if (event.key === Qt.Key_End) to = PickerNav.edge(rows, "", true);
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (!event.isAutoRepeat) grid.choose(grid.current);
            grid.keyboard = true;
            return true;
        } else {
            return false;
        }
        // The first key after the pointer shows the ring where it is.
        if (grid.keyboard && to >= 0) grid.current = to;
        grid.keyboard = true;
        grid.pointer = false;
        return true;
    }

    // A folder outside home (SHELL_FACE_PICTURES, or a long path) elides in
    // the middle rather than run past the sheet.
    Text {
        id: label
        width: grid.width
        leftPadding: 4
        rightPadding: 4
        elide: Text.ElideMiddle
        text: ("Pictures · " + grid.dirLabel).toUpperCase()
        color: Tokens.inkDim
        textFormat: Text.PlainText
        font.family: "Adwaita Sans"
        font.pixelSize: 11
        font.weight: Font.Medium
        font.letterSpacing: 0.66
    }

    Rectangle {
        id: emptyCard
        objectName: "faceGridEmpty"
        visible: grid.count === 0
        y: label.height + 6
        width: parent.width
        height: 54
        radius: 14
        color: Tokens.raised
        border.width: 1
        border.color: Tokens.hairline
        Text {
            anchors.verticalCenter: parent.verticalCenter
            x: 14
            width: parent.width - 28
            elide: Text.ElideRight
            text: grid.loaded ? "No images in " + grid.dirLabel : "Looking in " + grid.dirLabel + "…"
            color: Tokens.inkDim
            textFormat: Text.PlainText
            font.family: "Adwaita Sans"
            font.pixelSize: 13
        }
    }

    Item {
        id: cardsBox
        visible: grid.count > 0
        y: label.height + 6
        width: parent.width
        height: grid.count > 0 ? Math.ceil(grid.count / grid.columns) * (grid.cardHeight + grid.gap) - grid.gap : 0
        Repeater {
            id: cards
            // A count, not the array: a relisting with the same length keeps
            // the cards (and their decoded thumbnails).
            model: grid.count
            delegate: PickerCard {
                id: cardItem
                required property int index
                readonly property var entry: grid.pictures?.[index] ?? ({})
                objectName: "faceCard-" + index
                x: (index % grid.columns) * (grid.cardWidth + grid.gap)
                y: Math.floor(index / grid.columns) * (grid.cardHeight + grid.gap)
                width: grid.cardWidth
                height: grid.cardHeight
                imageHeight: grid.imageSize
                thumbRadius: grid.imageSize / 2
                thumbSize: Qt.size(160, 160)
                image: PickerNav.fileUrl(cardItem.entry.path ?? "")
                title: cardItem.entry.name ?? ""
                titleWeight: Font.Normal
                idleRing: true
                armed: grid.armed
                focused: index === grid.current && (grid.keyboard || grid.pointer)
                opacity: grid.busy && index !== grid.current ? 0.45 : 1
                accessibleName: "Use " + (cardItem.entry.name ?? "") + " as the profile picture"
                onHovered: {
                    grid.current = index;
                    grid.pointer = true;
                    grid.keyboard = false;
                }
                onClicked: grid.choose(index)
            }
        }
    }
}
