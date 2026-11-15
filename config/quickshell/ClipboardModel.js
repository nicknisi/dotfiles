function kindFor(preview) {
    var text = String(preview).toLowerCase();
    if (text.indexOf("binary data") < 0) return "text";
    if (/\b(png|jpe?g|gif|bmp|webp|tiff?)\b/.test(text)) return "image";
    if (/\bvideo\/[a-z0-9.+-]+\b|\b(mp4|webm|mkv|mov|avi|mpeg|mpg)\b/.test(text)) return "video";
    return "binary";
}

function extensionFor(preview, kind) {
    var text = String(preview).toLowerCase();
    if (kind === "image") {
        var image = text.match(/\b(png|jpe?g|gif|bmp|webp|tiff?)\b/);
        if (!image) return "img";
        if (image[1] === "jpeg") return "jpg";
        if (image[1] === "tif") return "tiff";
        return image[1];
    }
    if (kind === "video") {
        if (/video\/quicktime\b/.test(text)) return "mov";
        if (/video\/x-matroska\b/.test(text)) return "mkv";
        if (/video\/x-msvideo\b/.test(text)) return "avi";
        var video = text.match(/\b(mp4|webm|mkv|mov|avi|mpeg|mpg)\b/);
        return video ? video[1] : "video";
    }
    return "bin";
}

function mimeFor(preview, kind, extension) {
    var text = String(preview).toLowerCase();
    if (kind === "video") {
        var video = text.match(/\bvideo\/[a-z0-9.+-]+\b/);
        return video ? video[0] : "video/" + extension;
    }
    if (kind !== "image") return "";
    if (extension === "jpg") return "image/jpeg";
    if (extension === "tiff") return "image/tiff";
    return "image/" + extension;
}

function entry(id, preview) {
    var kind = kindFor(preview);
    var extension = extensionFor(preview, kind);
    return { id: id, preview: preview, kind: kind, extension: extension, mime: mimeFor(preview, kind, extension) };
}

// What cliphist says about a binary entry: "[[ binary data 1 MiB png 2855x1705 ]]"
// (images carry their size), or clipboard-list's "[[ binary data 42MiB video/mp4 ]]".
// null for text.
function binaryInfo(preview) {
    var m = /\[\[\s*binary data\s+([0-9.]+)\s*([KMGTP]?i?B)\s+([A-Za-z0-9.+\/-]+)(?:\s+([0-9]+)x([0-9]+))?\s*\]\]/.exec(String(preview));
    if (!m) return null;
    return { size: m[1] + " " + m[2], format: m[3].toLowerCase(), width: m[4] ? Number(m[4]) : 0, height: m[5] ? Number(m[5]) : 0 };
}

// A copied URL is a link: one token, a scheme or a www. host.
function isLink(text) {
    var t = String(text || "").trim();
    return /^(https?|ftp|file):\/\/\S+$/i.test(t) || /^www\.[^\s.]+\.\S+$/i.test(t);
}

// The launcher row's display facts for one entry (launcher-pickers 5.1):
// kind text | link | image | video | binary, the tile's icon, the meta line
// ("Image · 1 MiB"; cliphist keeps no timestamps, so size stands in for age),
// and for images the dimension line ("2855 × 1705 · image/png").
function meta(row) {
    var kind = row.kind === "text" && isLink(row.preview) ? "link" : row.kind;
    var info = kind === "text" || kind === "link" ? null : binaryInfo(row.preview);
    var label = kind.charAt(0).toUpperCase() + kind.slice(1);
    var icon = kind === "link" ? "link" : kind === "image" || kind === "video" ? "image" : "text";
    var dims = info && info.width > 0 ? info.width + " × " + info.height + (row.mime ? " · " + row.mime : "") : (row.mime || "");
    return {
        kind: kind, label: label, icon: icon,
        size: info ? info.size : "", format: info ? info.format : "",
        width: info ? info.width : 0, height: info ? info.height : 0,
        line: info ? label + " · " + info.size : label,
        dims: dims
    };
}

function filter(entries, text) {
    var needle = String(text || "").trim().toLowerCase();
    return entries.filter(function(row) {
        return !needle || (row.kind + " " + row.preview).toLowerCase().indexOf(needle) >= 0;
    }).slice(0, 100);
}

if (typeof module !== "undefined")
    module.exports = { kindFor: kindFor, extensionFor: extensionFor, mimeFor: mimeFor, entry: entry, filter: filter, binaryInfo: binaryInfo, isLink: isLink, meta: meta };
