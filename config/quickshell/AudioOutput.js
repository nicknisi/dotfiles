// PipeWire metadata varies by device/driver. Prefer Bluetooth transport, then
// advertised device type; unknown/virtual outputs keep the generic speaker.
// icon() is the Nerd Font glyph (the old menus), iconName() the Lucide icon
// (Kit/IconPaths.js) the bar draws since M4; both read kind().
function kind(node) {
    if (!node) return "speaker";
    const props = node.properties || {};
    if (props["device.api"] === "bluez5" || props["device.bus"] === "bluetooth"
        || String(node.name || "").startsWith("bluez_output."))
        return "bluetooth";
    const text = [props["device.form-factor"], props["device.icon-name"],
        props["device.profile.name"], node.name, node.nickname, node.description].join(" ").toLowerCase();
    if (/headset|hands.free/.test(text)) return "headset";
    if (/headphone/.test(text)) return "headphones";
    if (/hdmi|displayport/.test(text)) return "hdmi";
    return "speaker";
}

function iconName(node, muted) {
    if (muted) return "volMute";
    return { bluetooth: "bt", headset: "headphones", headphones: "headphones", hdmi: "monitor" }[kind(node)] || "vol";
}

function icon(node, muted) {
    if (muted) return "\u{f0581}";
    return { bluetooth: "\u{f00af}", headset: "\u{f02ce}", headphones: "\u{f02cb}", hdmi: "\u{f0379}" }[kind(node)] || "\u{f057e}";
}
