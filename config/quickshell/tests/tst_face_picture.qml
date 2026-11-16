import QtQuick
import QtTest
import qs
import qs.Kit

// Kit/FacePicture (the profile picture): the initial exactly as before when
// there is no picture; a picture cropped to the circle with the ring; the
// sources walked in order past an empty file, a non-image, a symlink loop
// and a missing file; a 50 MP image decoded off the UI thread, at twice the
// drawn size. kit.sh writes the images (tests/face-images.py: generated, no
// photo of anyone) next to this file.
Item {
    id: root
    width: 300
    height: 200

    readonly property string dir: Qt.resolvedUrl(".").toString()
    function url(name) {
        return root.dir + name;
    }

    FacePicture {
        id: face
        size: 44
        fontSize: 16
        initial: "N"
    }

    // The UI thread's pulse while a decode runs.
    property real lastTick: 0
    property real worstGap: 0
    Timer {
        id: pulse
        interval: 8
        repeat: true
        onTriggered: {
            const t = Date.now();
            if (root.lastTick > 0) root.worstGap = Math.max(root.worstGap, t - root.lastTick);
            root.lastTick = t;
        }
    }

    TestCase {
        name: "FacePicture"
        when: windowShown

        function init() {
            face.sources = [];
            face.size = 44;
            face.fontSize = 16;
            tryCompare(face, "pictureShown", false);
            // The last test's picture fades out first.
            tryCompare(face.ring, "visible", false, 2000);
        }

        function test_initial() {
            compare(face.width, 44);
            compare(face.height, 44);
            compare(face.initialText.text, "N");
            verify(face.initialText.visible, "the initial shows");
            compare(face.initialText.font.pixelSize, 16);
            compare(face.initialText.font.weight, Font.Medium);
            compare(face.initialText.color, Tokens.fg);
            verify(!face.ring.visible, "no ring on the initial, as before");
            compare(String(face.image.source), "");
        }

        function test_picture() {
            face.sources = [url("face.png")];
            tryCompare(face, "pictureShown", true, 3000);
            compare(face.shownSource, url("face.png"));
            compare(face.image.fillMode, Image.PreserveAspectCrop, "cropped to fill the circle");
            compare(face.image.sourceSize.width, 88, "decoded at twice the drawn size");
            compare(face.image.sourceSize.height, 88);
            verify(face.image.asynchronous, "off the UI thread");
            verify(!face.image.cache, "a replaced ~/.face loads afresh");
            tryCompare(face.ring, "opacity", 1, 2000);
            verify(face.ring.visible, "the 1 px ring with a picture");
            compare(face.ring.border.width, 1);
            compare(face.ring.border.color, Tokens.hairline);
            compare(face.ring.radius, 22);
            tryCompare(face.initialText, "visible", false, 2000);
            const cover = findChild(face, "facePicture");
            verify(cover !== null && cover.maskEnabled, "masked to the circle");
            // The mask's disc ends 1 px inside the ring's outer edge, so the
            // picture never tints the ring's outer antialiased pixels; its
            // texture is the circle's whole box (MultiEffect stretches it).
            const disc = findChild(face, "faceMaskDisc");
            verify(disc !== null, "the mask's disc");
            compare(disc.parent.width, 44, "the mask's texture is the whole box");
            compare(disc.x, 1);
            compare(disc.width, 42);
            compare(disc.radius, 21);
            // Another size: the decode follows it.
            face.size = 20;
            compare(face.image.sourceSize.width, 40);
            compare(face.ring.radius, 10);
            compare(disc.width, 18);
        }

        function test_walks_past_bad_files() {
            face.sources = [url("missing.png"), url("empty.png"), url("text.png"), url("loop.png"), url("face2.png")];
            tryCompare(face, "pictureShown", true, 4000);
            compare(face.tried, 4, "the first file that decodes");
            compare(face.shownSource, url("face2.png"));
        }

        function test_none_decode() {
            face.sources = [url("empty.png"), url("text.png"), url("loop.png"), url("missing.png")];
            tryCompare(face, "tried", 4, 4000);
            verify(!face.pictureShown);
            verify(face.initialText.visible, "back to the initial");
            verify(!face.ring.visible);
            compare(String(face.image.source), "");
        }

        function test_sources_change() {
            face.sources = [url("text.png")];
            tryCompare(face, "tried", 1, 3000);
            face.sources = [url("face.png")];
            compare(face.tried, 0, "a new list starts again");
            tryCompare(face, "pictureShown", true, 3000);
            face.sources = [];
            verify(!face.pictureShown, "no sources: the initial at once");
        }

        function test_big_image_never_blocks() {
            root.lastTick = 0;
            root.worstGap = 0;
            pulse.start();
            wait(50);
            const t0 = Date.now();
            face.sources = [url("big.png"), url("face2.png")];
            tryVerify(() => face.image.status === Image.Ready || face.tried >= 2, 10000, "the 50 MP file decodes or is refused");
            const took = Date.now() - t0;
            wait(50);
            pulse.stop();
            console.log("face: 50 MP png: " + (face.tried === 0 ? "decoded" : "refused") + " in " + took + " ms; worst UI gap " + root.worstGap + " ms");
            verify(root.worstGap < 120, "the UI thread kept ticking: worst gap " + root.worstGap + " ms");
            if (face.tried === 0) {
                compare(face.image.sourceSize.width, 88, "at 88 px, never 8192");
                verify(face.image.implicitWidth <= 176, "decoded small: " + face.image.implicitWidth);
            } else {
                tryCompare(face, "pictureShown", true, 3000);
                compare(face.shownSource, url("face2.png"), "refused: on to the next");
            }
        }
    }
}
