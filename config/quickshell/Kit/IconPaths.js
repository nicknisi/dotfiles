.pragma library
// IconPaths.js - the island shell's icons, as path data in a 24-unit viewBox.
//
// Kit/Icon.qml strokes these at STROKE units (1.8, from the mocks) with round
// caps and joins, scaled to 14, 16, 18 or 22 px. "solid" entries are filled as
// well as stroked (media transport), the mocks' .solid icons.
//
// Every entry naming "lucide" is that icon from lucide-static 1.65.0, its
// <path>, <circle>, <rect> and <line> elements written out as one path in
// document order. tests/icon-provenance.py rebuilds each one from the pinned
// package and fails on any difference, so do not hand-edit "d": change the
// "lucide" name and run `python3 -B tests/icon-provenance.py --write`.
// Entries with "lucide": null are drawn here, and say what they are in "origin".
//
// The design mocks drew simplified versions of most of these. Their paths could
// not be traced to a licensed source, so the Lucide originals replace them.
//
// Lucide's licence, which covers the paths below:
//
// ISC License
//
// Copyright (c) 2026 Lucide Icons and Contributors
//
// Permission to use, copy, modify, and/or distribute this software for any
// purpose with or without fee is hereby granted, provided that the above
// copyright notice and this permission notice appear in all copies.
//
// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
// WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
// ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
// WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
// ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
// OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
//
// Some of them (search, x, the chevrons, lock, log-out, monitor, moon, music,
// headphones, power, server, smartphone, terminal, type, link, plus, check,
// arrow-right, clipboard) are on Lucide's list of icons derived from Feather,
// which carries this notice as well:
//
// The MIT License (MIT) (for the icons listed above)
//
// Copyright (c) 2013-present Cole Bemis
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

// Stroke width in viewBox units. Icon.qml scales it with the icon.
var STROKE = 1.8;

// The table is JSON between the markers so the provenance check can read it.
// Names follow the mocks (chev, chevL, bt, vol); camelCase variants are states.
// BEGIN ICONS
var ICONS = {
    "search": {"lucide": "search", "d": "M21 21l-4.34 -4.34M3 11A8 8 0 1 0 19 11A8 8 0 1 0 3 11Z"},
    "x": {"lucide": "x", "d": "M18 6L6 18M6 6l12 12"},
    "check": {"lucide": "check", "d": "M20 6L9 17l-5 -5"},
    "plus": {"lucide": "plus", "d": "M5 12h14M12 5v14"},
    "chev": {"lucide": "chevron-right", "d": "M9 18l6 -6l-6 -6"},
    "chevL": {"lucide": "chevron-left", "d": "M15 18l-6 -6l6 -6"},
    "arrow": {"lucide": "arrow-right", "d": "M5 12h14M12 5l7 7l-7 7"},
    "wifi": {"lucide": "wifi", "d": "M12 20h0.01M2 8.82a15 15 0 0 1 20 0M5 12.859a10 10 0 0 1 14 0M8.5 16.429a5 5 0 0 1 7 0"},
    "wifi2": {"lucide": "wifi-high", "d": "M12 20h0.01M5 12.859a10 10 0 0 1 14 0M8.5 16.429a5 5 0 0 1 7 0"},
    "wifi1": {"lucide": "wifi-low", "d": "M12 20h0.01M8.5 16.429a5 5 0 0 1 7 0"},
    "wifiOff": {"lucide": "wifi-off", "d": "M12 20h0.01M8.5 16.429a5 5 0 0 1 7 0M5 12.859a10 10 0 0 1 5.17 -2.69M19 12.859a10 10 0 0 0 -2.007 -1.523M2 8.82a15 15 0 0 1 4.177 -2.643M22 8.82a15 15 0 0 0 -11.288 -3.764M2 2l20 20"},
    "bt": {"lucide": "bluetooth", "d": "M7 7l10 10l-5 5V2l5 5L7 17"},
    "btOff": {"lucide": "bluetooth-off", "d": "M17 17l-5 5V12l-5 5M2 2l20 20M14.5 9.5L17 7l-5 -5v4.5"},
    "tailscale": {"lucide": null, "origin": "the mocks' Tailscale mark: seven r=1.4 dots on the 5/12/19 grid, drawn as circles", "d": "M3.6 5A1.4 1.4 0 1 0 6.4 5A1.4 1.4 0 1 0 3.6 5ZM10.6 5A1.4 1.4 0 1 0 13.4 5A1.4 1.4 0 1 0 10.6 5ZM17.6 5A1.4 1.4 0 1 0 20.4 5A1.4 1.4 0 1 0 17.6 5ZM3.6 12A1.4 1.4 0 1 0 6.4 12A1.4 1.4 0 1 0 3.6 12ZM10.6 12A1.4 1.4 0 1 0 13.4 12A1.4 1.4 0 1 0 10.6 12ZM17.6 12A1.4 1.4 0 1 0 20.4 12A1.4 1.4 0 1 0 17.6 12ZM10.6 19A1.4 1.4 0 1 0 13.4 19A1.4 1.4 0 1 0 10.6 19Z"},
    "vol": {"lucide": "volume-2", "d": "M11 4.702a0.705 0.705 0 0 0 -1.203 -0.498L6.413 7.587A1.4 1.4 0 0 1 5.416 8H3a1 1 0 0 0 -1 1v6a1 1 0 0 0 1 1h2.416a1.4 1.4 0 0 1 0.997 0.413l3.383 3.384A0.705 0.705 0 0 0 11 19.298zM16 9a5 5 0 0 1 0 6M19.364 18.364a9 9 0 0 0 0 -12.728"},
    "vol1": {"lucide": "volume-1", "d": "M11 4.702a0.705 0.705 0 0 0 -1.203 -0.498L6.413 7.587A1.4 1.4 0 0 1 5.416 8H3a1 1 0 0 0 -1 1v6a1 1 0 0 0 1 1h2.416a1.4 1.4 0 0 1 0.997 0.413l3.383 3.384A0.705 0.705 0 0 0 11 19.298zM16 9a5 5 0 0 1 0 6"},
    "volMute": {"lucide": "volume-x", "d": "M11 4.702a0.7 0.7 0 0 0 -1.203 -0.498L6.413 7.587A1.4 1.4 0 0 1 5.416 8H3a1 1 0 0 0 -1 1v6a1 1 0 0 0 1 1h2.416a1.4 1.4 0 0 1 0.997 0.413l3.383 3.384A0.7 0.7 0 0 0 11 19.298zM16.5 14.5l5 -5M16.5 9.5l5 5"},
    "mic": {"lucide": "mic", "d": "M12 19v3M19 10v2a7 7 0 0 1 -14 0v-2M12 2H12A3 3 0 0 1 15 5V12A3 3 0 0 1 12 15H12A3 3 0 0 1 9 12V5A3 3 0 0 1 12 2Z"},
    "micOff": {"lucide": "mic-off", "d": "M12 19v3M15 9.34V5a3 3 0 0 0 -5.68 -1.33M16.95 16.95A7 7 0 0 1 5 12v-2M18.89 13.23A7 7 0 0 0 19 12v-2M2 2l20 20M9 9v3a3 3 0 0 0 5.12 2.12"},
    "battery": {"lucide": "battery", "d": "M22 14L22 10M4 6H16A2 2 0 0 1 18 8V16A2 2 0 0 1 16 18H4A2 2 0 0 1 2 16V8A2 2 0 0 1 4 6Z"},
    "batteryLow": {"lucide": "battery-low", "d": "M22 14v-4M6 14v-4M4 6H16A2 2 0 0 1 18 8V16A2 2 0 0 1 16 18H4A2 2 0 0 1 2 16V8A2 2 0 0 1 4 6Z"},
    "batteryCharging": {"lucide": "battery-charging", "d": "M11 7l-3 5h4l-3 5M14.856 6H16a2 2 0 0 1 2 2v8a2 2 0 0 1 -2 2h-2.935M22 14v-4M5.14 18H4a2 2 0 0 1 -2 -2V8a2 2 0 0 1 2 -2h2.936"},
    "sun": {"lucide": "sun", "d": "M8 12A4 4 0 1 0 16 12A4 4 0 1 0 8 12ZM12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M6.34 17.66l-1.41 1.41M19.07 4.93l-1.41 1.41"},
    "moon": {"lucide": "moon", "d": "M20.985 12.486a9 9 0 1 1 -9.473 -9.472c0.405 -0.022 0.617 0.46 0.402 0.803a6 6 0 0 0 8.268 8.268c0.344 -0.215 0.825 -0.004 0.803 0.401"},
    "coffee": {"lucide": "coffee", "d": "M10 2v2M14 2v2M16 8a1 1 0 0 1 1 1v8a4 4 0 0 1 -4 4H7a4 4 0 0 1 -4 -4V9a1 1 0 0 1 1 -1h14a4 4 0 1 1 0 8h-1M6 2v2"},
    "zap": {"lucide": "zap", "d": "M15.914 4a1.5 1.5 0 0 0 -2.474 -1.561l-9 9A1.5 1.5 0 0 0 5.5 14h4.002a0.5 0.5 0 0 1 0.471 0.666L8.086 20a1.5 1.5 0 0 0 2.475 1.56l9 -9A1.5 1.5 0 0 0 18.5 10h-3.997a0.5 0.5 0 0 1 -0.472 -0.667z"},
    "bell": {"lucide": "bell", "d": "M10.268 21a2 2 0 0 0 3.464 0M3.262 15.326A1 1 0 0 0 4 17h16a1 1 0 0 0 0.74 -1.673C19.41 13.956 18 12.499 18 8A6 6 0 0 0 6 8c0 4.499 -1.411 5.956 -2.738 7.326"},
    "bellOff": {"lucide": "bell-off", "d": "M10.268 21a2 2 0 0 0 3.464 0M17 17H4a1 1 0 0 1 -0.74 -1.673C4.59 13.956 6 12.499 6 8a6 6 0 0 1 0.258 -1.742M2 2l20 20M8.668 3.01A6 6 0 0 1 18 8c0 2.687 0.77 4.653 1.707 6.05"},
    "monitor": {"lucide": "monitor", "d": "M4 3H20A2 2 0 0 1 22 5V15A2 2 0 0 1 20 17H4A2 2 0 0 1 2 15V5A2 2 0 0 1 4 3ZM8 21L16 21M12 17L12 21"},
    "palette": {"lucide": "palette", "d": "M12 22a1 1 0 0 1 0 -20a10 9 0 0 1 10 9a5 5 0 0 1 -5 5h-2.25a1.75 1.75 0 0 0 -1.4 2.8l0.3 0.4a1.75 1.75 0 0 1 -1.4 2.8zM13 6.5A0.5 0.5 0 1 0 14 6.5A0.5 0.5 0 1 0 13 6.5ZM17 10.5A0.5 0.5 0 1 0 18 10.5A0.5 0.5 0 1 0 17 10.5ZM6 12.5A0.5 0.5 0 1 0 7 12.5A0.5 0.5 0 1 0 6 12.5ZM8 7.5A0.5 0.5 0 1 0 9 7.5A0.5 0.5 0 1 0 8 7.5Z"},
    "record": {"lucide": "circle-dot", "d": "M11 12A1 1 0 1 0 13 12A1 1 0 1 0 11 12ZM2 12A10 10 0 1 0 22 12A10 10 0 1 0 2 12Z"},
    "clip": {"lucide": "clipboard", "d": "M9 2H15A1 1 0 0 1 16 3V5A1 1 0 0 1 15 6H9A1 1 0 0 1 8 5V3A1 1 0 0 1 9 2ZM16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1 -2 2H6a2 2 0 0 1 -2 -2V6a2 2 0 0 1 2 -2h2"},
    "sparkle": {"lucide": "sparkle", "d": "M11.017 2.814a1 1 0 0 1 1.966 0l1.051 5.558a2 2 0 0 0 1.594 1.594l5.558 1.051a1 1 0 0 1 0 1.966l-5.558 1.051a2 2 0 0 0 -1.594 1.594l-1.051 5.558a1 1 0 0 1 -1.966 0l-1.051 -5.558a2 2 0 0 0 -1.594 -1.594l-5.558 -1.051a1 1 0 0 1 0 -1.966l5.558 -1.051a2 2 0 0 0 1.594 -1.594z"},
    "lock": {"lucide": "lock", "d": "M5 11H19A2 2 0 0 1 21 13V20A2 2 0 0 1 19 22H5A2 2 0 0 1 3 20V13A2 2 0 0 1 5 11ZM7 11V7a5 5 0 0 1 10 0v4"},
    "power": {"lucide": "power", "d": "M12 2v10M18.4 6.6a9 9 0 1 1 -12.77 0.04"},
    "logout": {"lucide": "log-out", "d": "M16 17l5 -5l-5 -5M21 12H9M9 21H5a2 2 0 0 1 -2 -2V5a2 2 0 0 1 2 -2h4"},
    "restart": {"lucide": "rotate-ccw", "d": "M3 12a9 9 0 1 0 9 -9a9.75 9.75 0 0 0 -6.74 2.74L3 8M3 3v5h5"},
    "shield": {"lucide": "shield", "d": "M20 13c0 5 -3.5 7.5 -7.66 8.95a1 1 0 0 1 -0.67 -0.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1 -1c2 0 4.5 -1.2 6.24 -2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"},
    "prev": {"lucide": "skip-back", "solid": true, "d": "M17.971 4.285A2 2 0 0 1 21 6v12a2 2 0 0 1 -3.029 1.715l-9.997 -5.998a2 2 0 0 1 -0.003 -3.432zM3 20V4"},
    "next": {"lucide": "skip-forward", "solid": true, "d": "M21 4v16M6.029 4.285A2 2 0 0 0 3 6v12a2 2 0 0 0 3.029 1.715l9.997 -5.998a2 2 0 0 0 0.003 -3.432z"},
    "play": {"lucide": "play", "solid": true, "d": "M5 5a2 2 0 0 1 3.008 -1.728l11.997 6.998a2 2 0 0 1 0.003 3.458l-12 7A2 2 0 0 1 5 19z"},
    "pause": {"lucide": "pause", "solid": true, "d": "M15 3H18A1 1 0 0 1 19 4V20A1 1 0 0 1 18 21H15A1 1 0 0 1 14 20V4A1 1 0 0 1 15 3ZM6 3H9A1 1 0 0 1 10 4V20A1 1 0 0 1 9 21H6A1 1 0 0 1 5 20V4A1 1 0 0 1 6 3Z"},
    "music": {"lucide": "music", "d": "M21 16V3a1 1 0 0 0 -1.28 -0.96l-10 2.917a1 1 0 0 0 -0.72 0.96V19M15 16A3 3 0 1 0 21 16A3 3 0 1 0 15 16ZM3 19A3 3 0 1 0 9 19A3 3 0 1 0 3 19Z"},
    "speaker": {"lucide": "speaker", "d": "M6 2H18A2 2 0 0 1 20 4V20A2 2 0 0 1 18 22H6A2 2 0 0 1 4 20V4A2 2 0 0 1 6 2ZM12 6h0.01M8 14A4 4 0 1 0 16 14A4 4 0 1 0 8 14ZM12 14h0.01"},
    "headphones": {"lucide": "headphones", "d": "M3 14h3a2 2 0 0 1 2 2v3a2 2 0 0 1 -2 2H5a2 2 0 0 1 -2 -2v-7a9 9 0 0 1 18 0v7a2 2 0 0 1 -2 2h-1a2 2 0 0 1 -2 -2v-3a2 2 0 0 1 2 -2h3"},
    "video": {"lucide": "video", "d": "M16 13l5.223 3.482a0.5 0.5 0 0 0 0.777 -0.416V7.87a0.5 0.5 0 0 0 -0.752 -0.432L16 10.5M4 6H14A2 2 0 0 1 16 8V16A2 2 0 0 1 14 18H4A2 2 0 0 1 2 16V8A2 2 0 0 1 4 6Z"},
    "globe": {"lucide": "globe", "d": "M2 12A10 10 0 1 0 22 12A10 10 0 1 0 2 12ZM12 2a14.5 14.5 0 0 0 0 20a14.5 14.5 0 0 0 0 -20M2 12h20"},
    "laptop": {"lucide": "laptop", "d": "M18 5a2 2 0 0 1 2 2v8.526a2 2 0 0 0 0.212 0.897l1.068 2.127a1 1 0 0 1 -0.9 1.45H3.62a1 1 0 0 1 -0.9 -1.45l1.068 -2.127A2 2 0 0 0 4 15.526V7a2 2 0 0 1 2 -2zM20.054 15.987H3.946"},
    "server": {"lucide": "server", "d": "M4 2H20A2 2 0 0 1 22 4V8A2 2 0 0 1 20 10H4A2 2 0 0 1 2 8V4A2 2 0 0 1 4 2ZM4 14H20A2 2 0 0 1 22 16V20A2 2 0 0 1 20 22H4A2 2 0 0 1 2 20V16A2 2 0 0 1 4 14ZM6 6L6.01 6M6 18L6.01 18"},
    "phone": {"lucide": "smartphone", "d": "M7 2H17A2 2 0 0 1 19 4V20A2 2 0 0 1 17 22H7A2 2 0 0 1 5 20V4A2 2 0 0 1 7 2ZM12 18h0.01"},
    "terminal": {"lucide": "terminal", "d": "M12 19h8M4 17l6 -6l-6 -6"},
    "branch": {"lucide": "git-branch", "d": "M15 6a9 9 0 0 0 -9 9V3M15 6A3 3 0 1 0 21 6A3 3 0 1 0 15 6ZM3 18A3 3 0 1 0 9 18A3 3 0 1 0 3 18Z"},
    "window": {"lucide": "app-window", "d": "M4 4H20A2 2 0 0 1 22 6V18A2 2 0 0 1 20 20H4A2 2 0 0 1 2 18V6A2 2 0 0 1 4 4ZM10 4v4M2 8h20M6 4v4"},
    "crop": {"lucide": "crop", "d": "M6 2v14a2 2 0 0 0 2 2h14M18 22V8a2 2 0 0 0 -2 -2H2"},
    "pen": {"lucide": "pen", "d": "M21.174 6.812a1 1 0 0 0 -3.986 -3.987L3.842 16.174a2 2 0 0 0 -0.5 0.83l-1.321 4.352a0.5 0.5 0 0 0 0.623 0.622l4.353 -1.32a2 2 0 0 0 0.83 -0.497z"},
    "text": {"lucide": "type", "d": "M12 4v16M4 7V5a1 1 0 0 1 1 -1h14a1 1 0 0 1 1 1v2M9 20h6"},
    "image": {"lucide": "image", "d": "M5 3H19A2 2 0 0 1 21 5V19A2 2 0 0 1 19 21H5A2 2 0 0 1 3 19V5A2 2 0 0 1 5 3ZM7 9A2 2 0 1 0 11 9A2 2 0 1 0 7 9ZM21 15l-3.086 -3.086a2 2 0 0 0 -2.828 0L6 21"},
    "link": {"lucide": "link", "d": "M10 13a5 5 0 0 0 7.54 0.54l3 -3a5 5 0 0 0 -7.07 -7.07l-1.72 1.71M14 11a5 5 0 0 0 -7.54 -0.54l-3 3a5 5 0 0 0 7.07 7.07l1.71 -1.71"},
    "sliders": {"lucide": "sliders-vertical", "d": "M10 8h4M12 21v-9M12 8V3M17 16h4M19 12V3M19 21v-5M3 14h4M5 10V3M5 21v-7"}
};
// END ICONS

// Other names the specs use for the same drawings.
var ALIASES = { "ts": "tailscale", "exit": "logout" };

// Every drawable name, aliases excluded, in table order.
var NAMES = Object.keys(ICONS);

function resolve(name) {
    var key = String(name || "");
    if (Object.prototype.hasOwnProperty.call(ICONS, key))
        return key;
    return Object.prototype.hasOwnProperty.call(ALIASES, key) ? ALIASES[key] : "";
}

function has(name) {
    return resolve(name) !== "";
}

// Path data for a name, or "" when there is no such icon.
function path(name) {
    var key = resolve(name);
    return key ? ICONS[key].d : "";
}

function isSolid(name) {
    var key = resolve(name);
    return key ? ICONS[key].solid === true : false;
}
