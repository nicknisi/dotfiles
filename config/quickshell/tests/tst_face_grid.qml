import QtQuick
import QtTest
import qs
import qs.Panels

// Panels/FaceGrid (the Profile picture sheet's picker): the wallpaper
// picker's cards in six columns with circular images, the keys (Left and
// Right wrap, Up and Down by a row, Home, End, Enter chooses), the pointer
// moving the focus, nothing chosen while busy, and the empty states.
Item {
    id: root
    width: 760
    height: 560

    function pics(n) {
        const out = [];
        for (let i = 0; i < n; i++)
            out.push({ name: "pic" + i + ".png", path: "/home/u/Pictures/pic" + i + ".png", mtime: 100 - i, size: 10 });
        return out;
    }

    FaceGrid {
        id: grid
        x: 16
        y: 16
        width: 728
        pictures: root.pics(9)
        loaded: true
    }

    SignalSpy {
        id: chosen
        target: grid
        signalName: "chosen"
    }

    TestCase {
        name: "FaceGrid"
        when: windowShown
        visible: true

        function key(k, mods) {
            return grid.key({ key: k, modifiers: mods || 0, isAutoRepeat: false });
        }

        function init() {
            grid.pictures = root.pics(9);
            grid.loaded = true;
            grid.busy = false;
            grid.current = 0;
            grid.keyboard = false;
            grid.pointer = false;
            chosen.clear();
            wait(0);
        }

        function test_layout() {
            compare(grid.columns, 6);
            compare(grid.repeater.count, 9);
            const c0 = grid.card(0), c5 = grid.card(5), c6 = grid.card(6);
            compare(c0.width, Math.floor((728 - 5 * 12) / 6));
            compare(c5.x + c5.width <= 728, true, "six fit across");
            compare(c6.x, 0, "the seventh starts the second row");
            compare(c6.y, grid.cardHeight + 12);
            compare(c0.thumb.width, c0.width - 12);
            compare(c0.thumb.height, c0.thumb.width, "square images");
            compare(c0.thumb.radius, c0.thumb.width / 2, "cropped to circles");
            compare(c0.title, "pic0.png");
            verify(c0.idleRing, "the wallpaper cards' hairline");
            compare(c0.image, "file:///home/u/Pictures/pic0.png");
            compare(grid.label.text, "PICTURES · ~/PICTURES");
            compare(grid.label.width, 728, "the label is the grid's width");
            verify(!grid.label.truncated);
            grid.dirLabel = "/tmp/a/very/long/folder/name/that/runs/past/the/sheet/" + "x".repeat(120);
            verify(grid.label.truncated, "a long folder elides");
            verify(grid.label.contentWidth <= 728);
            grid.dirLabel = "~/Pictures";
            compare(grid.implicitHeight, grid.label.height + 6 + 2 * grid.cardHeight + 12);
            verify(!c0.focused, "no ring until the keys or the pointer");
        }

        function test_keys() {
            verify(key(Qt.Key_Right), "taken");
            verify(grid.keyboard && grid.card(0).focused, "the first key shows the ring where it is");
            compare(grid.current, 0);
            key(Qt.Key_Right);
            compare(grid.current, 1);
            key(Qt.Key_Left);
            key(Qt.Key_Left);
            compare(grid.current, 8, "Left wraps");
            key(Qt.Key_Up);
            compare(grid.current, 2, "Up by a row");
            key(Qt.Key_Down);
            compare(grid.current, 8);
            key(Qt.Key_Down);
            compare(grid.current, 8, "the last row holds");
            key(Qt.Key_Home);
            compare(grid.current, 0);
            key(Qt.Key_End);
            compare(grid.current, 8);
            key(Qt.Key_J, Qt.ControlModifier);
            compare(grid.current, 8);
            key(Qt.Key_K, Qt.ControlModifier);
            compare(grid.current, 2, "Ctrl+K: up");
            verify(key(Qt.Key_Return));
            compare(chosen.count, 1);
            compare(chosen.signalArguments[0][0], "/home/u/Pictures/pic2.png");
            verify(!key(Qt.Key_A), "a letter is the sheet's");
            verify(!key(Qt.Key_Escape), "Esc goes back, the frame's");
        }

        function test_pointer() {
            mouseMove(grid.card(3), 20, 20);
            tryCompare(grid, "current", 3);
            verify(grid.pointer && grid.card(3).focused, "the pointer moves the focus");
            mouseClick(grid.card(4), 20, 20);
            compare(chosen.count, 1);
            compare(chosen.signalArguments[0][0], "/home/u/Pictures/pic4.png");
            key(Qt.Key_Right);
            compare(grid.current, 4, "the first key after the pointer shows the ring where it is");
            verify(grid.keyboard && !grid.pointer);
        }

        function test_busy() {
            grid.busy = true;
            grid.current = 1;
            key(Qt.Key_Right);
            key(Qt.Key_Return);
            mouseClick(grid.card(3), 20, 20);
            compare(chosen.count, 0, "nothing chosen while one saves");
            compare(grid.card(0).opacity, 0.45);
            compare(grid.card(grid.current).opacity, 1, "the one saving stays");
        }

        function test_empty() {
            grid.pictures = [];
            const empty = findChild(grid, "faceGridEmpty");
            verify(empty.visible);
            compare(empty.children[0].text, "No images in ~/Pictures");
            grid.loaded = false;
            compare(empty.children[0].text, "Looking in ~/Pictures…");
            verify(!key(Qt.Key_Right), "no cards, no keys taken");
            compare(grid.implicitHeight, grid.label.height + 6 + 54);
            grid.pictures = root.pics(2);
            verify(!empty.visible);
            compare(grid.current, 0);
        }

        function test_shrinking_list_keeps_current_in_range() {
            grid.current = 8;
            grid.pictures = root.pics(3);
            compare(grid.current, 2);
        }
    }
}
