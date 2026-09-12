import QtQuick
import Quickshell

ShellRoot {
    FloatingWindow {
        id: window
        implicitWidth: 198
        implicitHeight: 253
        visible: true
        PreviewPane { id: preview; anchors.fill: parent }
    }
    Timer {
        interval: 30
        running: true
        repeat: true
        property int step: 0
        onTriggered: {
            const image = decodeURIComponent(Qt.resolvedUrl("image.svg").toString().replace("file://", ""));
            const caption = preview.children.find(child => child.room !== undefined);
            const picture = preview.children.find(child => child.fit !== undefined);
            if (step > 0 && (!Number.isFinite(caption.height) || caption.height < 0
                    || (preview.image && caption.height > preview.captionBudget(caption.font.pixelSize, caption.room) + 0.01)
                    || (!preview.image && caption.height !== caption.room)
                    || (picture.visible && (picture.width > picture.boxWidth + 1 || picture.height > picture.boxHeight + 1)))) {
                console.error("PREVIEW_TEST_FAIL: caption or image exceeds its space");
                Qt.quit(); return;
            }
            if (step === 40) {
                console.log("PREVIEW_TEST_PASS");
                Qt.quit(); return;
            }
            const rows = [
                {},
                {previewImage: image, previewLabel: "THEME"},
                {previewImage: image, preview: "Short caption"},
                {previewImage: image, preview: "A long caption with a full file path: /home/example/Pictures/some-long-directory-name/a-long-image-file-name.svg"},
                {preview: "Text without an image still uses the available pane height."}
            ];
            if (step % 10 === 0) window.implicitWidth = step % 20 === 0 ? 198 : 180;
            preview.row = rows[step++ % rows.length];
        }
    }
}
