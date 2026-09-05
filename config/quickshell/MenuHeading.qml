// MenuHeading.qml - the section label inside a bar menu.
//
// Its own file rather than an inline component inside BarMenu, because inline
// components are not in scope as bare names in the files that derive from their
// declaring type: BtMenu inherits BarMenu but would still have to spell it
// BarMenu.MenuHeading. Every other shared piece in this directory is a file, so
// these are too.
import QtQuick
import QtQuick.Layouts

Text {
    font.family: Theme.font
    font.pixelSize: Theme.fontSize - 3
    font.bold: true
    font.letterSpacing: 1.2
    font.capitalization: Font.AllUppercase
    color: Theme.muted
    Layout.topMargin: 3
}
