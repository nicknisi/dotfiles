import QtQuick
import qs
import qs.Panels
import "../../lib/FaceModel.js" as FaceModel

// FaceSheet.qml - the profile picture: which file the circles draw, a
// picker over ~/Pictures, and Remove. The control center footer's circle
// and name open it (`island open cc/face`, `bar open cc/face`), and so does the
// launcher's System > Profile picture.
//
//   [‹] Profile picture                         From ~/.face
//   PICTURES · ~/PICTURES
//   (  ) (  ) (  ) (  ) (  ) (  )               Panels/FaceGrid.qml
//   [               Remove picture  ›                     ]
//
// The status: Saving…, From ~/.face, From AccountsService (Remove has
// nothing of ours to remove then) or Initial. A card copies its file to
// ~/.face (Face.set: checked, decoded, then a temp file in the same
// directory renamed over it, never a symlink); Remove deletes ~/.face
// (Face.clear) and the AccountsService icon, else the initial, comes back.
// A file that will not do (not an image, larger than 32 MiB) shows as an
// error row and ~/.face stays as it was.
//
// Showing: Face.refresh() and one listing of ~/Pictures (two levels deep,
// newest first, 120 at most). Under a dry run (the sandbox without a
// scratch home, SHELL_DRY_RUN=1) Face writes nothing and `ran` says what a
// press would have done.
SheetFrame {
    id: sheet

    // What the last press asked for: "set PATH", "clear". Tests and the sandbox.
    property string ran: ""
    readonly property var grid: sheet.contentItem

    objectName: "ccSheet-face"
    title: "Profile picture"
    sheetData: FaceModel.sheet({ kind: Face.kind, busy: Face.busy, error: Face.error })

    onShownChanged: {
        if (!sheet.shown) {
            if (sheet.grid) sheet.grid.keyboard = sheet.grid.pointer = false;
            return;
        }
        Face.refresh();
        Face.listPictures();
    }
    onKeyboardChanged: if (sheet.grid && sheet.keyboard) sheet.grid.keyboard = true
    keyHandler: event => sheet.grid ? sheet.grid.key(event) : false
    onFooterClicked: {
        sheet.ran = "clear";
        Face.clear();
    }

    content: Component {
        FaceGrid {
            pictures: Face.pictures
            loaded: Face.picturesLoaded
            dirLabel: FaceModel.tilde(Face.picturesDir, Face.home)
            busy: Face.busy
            keyboard: sheet.keyboard
            onChosen: path => {
                sheet.ran = "set " + path;
                Face.set(path);
            }
            onCurrentChanged: {
                const c = card(current);
                if (c) sheet.body.ensureVisible(c);
            }
        }
    }
}
