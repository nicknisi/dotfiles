// Stardate.js - the Bridge look's clock (personal-looks 2.5, PLAN M9).
//
// The fan count OmniWM's Bridge look uses (config/omniwm/shell/bridge/lib/
// look.luau, stardate()): (year - 1946) x 1000, plus the fraction of the year
// gone, x 1000, one decimal. The fraction counts whole days before today
// (yday - 1) plus today's hours and minutes, over 365 in every year, so the
// last day of a leap year runs a little past the next year's start, exactly
// as the Lua does. 2026-11-14 10:45 is 80869.7 (the Looks board's).
//
// Local time, like os.date("*t"). Pure functions, no QML types, so
// tests/stardate.cjs can require() this file.

// The day of the year, 1 on 1 January (os.date's yday), in local time.
function dayOfYear(date) {
    var start = new Date(date.getFullYear(), 0, 1);
    // Calendar days, counted on the date alone, so a daylight-saving hour
    // never shortens one.
    var a = Date.UTC(start.getFullYear(), start.getMonth(), start.getDate());
    var b = Date.UTC(date.getFullYear(), date.getMonth(), date.getDate());
    return Math.round((b - a) / 86400000) + 1;
}

// The number, unrounded.
function value(date) {
    var d = date instanceof Date ? date : new Date(date);
    var fraction = ((dayOfYear(d) - 1) + (d.getHours() + d.getMinutes() / 60) / 24) / 365;
    return (d.getFullYear() - 1946) * 1000 + fraction * 1000;
}

// "80869.7": one decimal, as string.format("%.1f") prints it. toFixed
// rounds the exact binary value, as printf does, but an exact tie goes up
// where printf goes to the even digit, and minutes do land on ties
// (10:57 on 1 January 2026 is exactly 80001.25: printf says 80001.2).
function format(date) {
    var v = value(date);
    var t = v * 10;
    if (Number.isInteger(v * 20) && !Number.isInteger(t)) {
        var even = Math.floor(t);
        if (even % 2 !== 0) even += 1;
        return (even / 10).toFixed(1);
    }
    return v.toFixed(1);
}

if (typeof module !== "undefined")
    module.exports = { dayOfYear: dayOfYear, value: value, format: format };
