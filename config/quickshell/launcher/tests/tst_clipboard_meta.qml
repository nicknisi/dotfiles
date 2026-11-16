import QtQuick
import QtTest
import "../../ClipboardModel.js" as ClipboardModel

// The clipboard scope's row and preview facts (launcher-pickers 5.1), parsed
// from what cliphist prints: no timestamps, so size stands in for age.
TestCase {
    name: "ClipboardMeta"

    function test_image_preview_carries_size_format_and_dimensions() {
        var info = ClipboardModel.binaryInfo("[[ binary data 1 MiB png 2855x1705 ]]")
        compare(info.size, "1 MiB")
        compare(info.format, "png")
        compare(info.width, 2855)
        compare(info.height, 1705)
        var row = ClipboardModel.entry("206", "[[ binary data 1 MiB png 2855x1705 ]]")
        var m = ClipboardModel.meta(row)
        compare(m.kind, "image")
        compare(m.icon, "image")
        compare(m.line, "Image · 1 MiB")
        compare(m.dims, "2855 × 1705 · image/png")
    }
    function test_fractional_sizes_and_jpeg() {
        var m = ClipboardModel.meta(ClipboardModel.entry("7", "[[ binary data 3.2 MiB jpeg 5000x3542 ]]"))
        compare(m.size, "3.2 MiB")
        compare(m.line, "Image · 3.2 MiB")
        compare(m.dims, "5000 × 3542 · image/jpeg")
    }
    function test_video_from_clipboard_list() {
        // bin/clipboard-list writes numfmt's "42MiB" and the MIME type.
        var m = ClipboardModel.meta(ClipboardModel.entry("9", "[[ binary data 42MiB video/mp4 ]]"))
        compare(m.kind, "video")
        compare(m.icon, "image")
        compare(m.size, "42 MiB")
        compare(m.width, 0)
        compare(m.line, "Video · 42 MiB")
        compare(m.dims, "video/mp4")
    }
    function test_text_and_links() {
        var text = ClipboardModel.meta(ClipboardModel.entry("1", "capture shot region"))
        compare(text.kind, "text")
        compare(text.icon, "text")
        compare(text.line, "Text")
        compare(text.dims, "")
        var link = ClipboardModel.meta(ClipboardModel.entry("2", "https://github.com/nicknisi/dotfiles"))
        compare(link.kind, "link")
        compare(link.icon, "link")
        compare(link.line, "Link")
        verify(ClipboardModel.isLink("www.example.com/a"))
        verify(!ClipboardModel.isLink("see https://example.com"), "prose with a URL inside is text")
        verify(!ClipboardModel.isLink("binary data"))
    }
    function test_unparseable_binary_keeps_its_kind() {
        compare(ClipboardModel.binaryInfo("copied text"), null)
        var m = ClipboardModel.meta(ClipboardModel.entry("3", "[[ binary data unknown ]]"))
        compare(m.kind, "binary")
        compare(m.line, "Binary")
    }
}
