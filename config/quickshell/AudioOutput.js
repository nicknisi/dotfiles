// PipeWire metadata varies by device/driver. Prefer Bluetooth transport, then
// advertised device type; unknown/virtual outputs keep the generic speaker.
function icon(node, muted) {
    if (muted) return "\u{f0581}";
    if (!node) return "\u{f057e}";
    const props = node.properties || {};
    if (props["device.api"] === "bluez5" || props["device.bus"] === "bluetooth"
        || String(node.name || "").startsWith("bluez_output."))
        return "\u{f00af}";
    const kind = [props["device.form-factor"], props["device.icon-name"],
        props["device.profile.name"], node.name, node.nickname, node.description].join(" ").toLowerCase();
    if (/headset|hands.free/.test(kind)) return "\u{f02ce}";
    if (/headphone/.test(kind)) return "\u{f02cb}";
    if (/hdmi|displayport/.test(kind)) return "\u{f0379}";
    return "\u{f057e}";
}
