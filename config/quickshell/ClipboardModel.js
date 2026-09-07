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

function filter(entries, text) {
    var needle = String(text || "").trim().toLowerCase();
    return entries.filter(function(row) {
        return !needle || (row.kind + " " + row.preview).toLowerCase().indexOf(needle) >= 0;
    }).slice(0, 100);
}

if (typeof module !== "undefined")
    module.exports = { kindFor: kindFor, extensionFor: extensionFor, mimeFor: mimeFor, entry: entry, filter: filter };
