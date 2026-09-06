function fail(message) {
    throw new Error("tailscale: " + message);
}

function object(value) {
    return value !== null && typeof value === "object" && typeof value.length !== "number";
}

function cleanDns(name) {
    var value = String(name || "");
    return value.charAt(value.length - 1) === "." ? value.slice(0, -1) : value;
}

function firstIp(ips, version) {
    if (!ips || typeof ips.length !== "number") return "";
    for (var i = 0; i < ips.length; i++) {
        var ip = String(ips[i] || "");
        if (version === 4 && /^100\./.test(ip)) return ip;
        if (version === 6 && /^fd7a:115c:a1e0:/i.test(ip)) return ip;
    }
    return "";
}

function nameOf(host, dns) {
    var hostName = String(host || "");
    if (hostName !== "" && hostName.toLowerCase() !== "localhost") return hostName;
    var short = cleanDns(dns).split(".")[0];
    return short || hostName || "Unknown";
}

function isMullvadName(name) {
    var value = cleanDns(name).toLowerCase();
    var suffix = ".mullvad.ts.net";
    return value.length > suffix.length && value.slice(value.length - suffix.length) === suffix;
}

function hasFileSharing(self) {
    var cap = "https://tailscale.com/cap/file-sharing";
    var map = self && self.CapMap;
    if (object(map) && map[cap] !== undefined) return true;
    var list = (self && self.Capabilities) || [];
    for (var i = 0; i < list.length; i++) if (String(list[i]) === cap) return true;
    return false;
}

function canSend(peer, selfUserId, fileSharing, running) {
    if (!running || !fileSharing || !peer.online) return false;
    if (typeof peer._taildrop === "number" && peer._taildrop !== 0) return peer._taildrop === 1;
    return peer.userId !== "" && peer.userId === String(selfUserId || "");
}

function peerFromStatus(id, raw, selfUserId, fileSharing, running) {
    if (!object(raw)) fail("bad peer schema");
    var ips = raw.TailscaleIPs || [];
    var peer = {
        id: String(id || ""),
        name: nameOf(raw.HostName, raw.DNSName),
        dns: cleanDns(raw.DNSName),
        ipv4: firstIp(ips, 4),
        ipv6: firstIp(ips, 6),
        userId: String(raw.UserID || ""),
        online: raw.Online === true,
        os: String(raw.OS || ""),
        exitNode: raw.ExitNode === true,
        exitNodeOption: raw.ExitNodeOption === true,
        mullvad: isMullvadName(raw.DNSName) || isMullvadName(raw.HostName),
        canSend: false,
        _taildrop: typeof raw.TaildropTarget === "number" ? raw.TaildropTarget : null
    };
    peer.canSend = canSend(peer, selfUserId, fileSharing, running);
    return peer;
}

function publicPeer(peer) {
    return {
        id: peer.id,
        name: peer.name,
        dns: peer.dns,
        ipv4: peer.ipv4,
        ipv6: peer.ipv6,
        userId: peer.userId,
        online: peer.online,
        os: peer.os,
        exitNode: peer.exitNode,
        exitNodeOption: peer.exitNodeOption,
        mullvad: peer.mullvad,
        canSend: peer.canSend
    };
}

function parseStatus(raw) {
    var text = String(raw || "").trim();
    if (text === "") fail("empty status json");

    var data;
    try { data = JSON.parse(text); } catch (error) { fail("invalid status json: " + error.message); }
    if (!object(data)) fail("status json must be an object");

    var backendState = String(data.BackendState || "");
    if (backendState === "") fail("status missing BackendState");
    var selfRaw = data.Self || {};
    if (!object(selfRaw)) fail("bad Self schema");
    var peersRaw = data.Peer || {};
    if (!object(peersRaw)) fail("bad Peer schema");

    var running = backendState === "Running";
    var selfIps = selfRaw.TailscaleIPs || data.TailscaleIPs || [];
    var self = {
        name: nameOf(selfRaw.HostName, selfRaw.DNSName),
        dns: cleanDns(selfRaw.DNSName),
        ipv4: firstIp(selfIps, 4),
        ipv6: firstIp(selfIps, 6),
        userId: String(selfRaw.UserID || "")
    };
    var fileSharing = running && hasFileSharing(selfRaw);
    var peers = [];
    var exitNodes = [];
    var selected = null;

    for (var id in peersRaw) {
        var peer = peerFromStatus(id, peersRaw[id], self.userId, fileSharing, running);
        if (peer.exitNode) selected = publicPeer(peer);
        if (peer.mullvad) continue;
        if (peer.online) peers.push(publicPeer(peer));
        if (peer.exitNodeOption && (peer.online || peer.exitNode)) exitNodes.push(publicPeer(peer));
    }

    peers.sort(function(a, b) { return a.name.localeCompare(b.name); });
    exitNodes.sort(function(a, b) { return a.name.localeCompare(b.name); });

    return {
        backendState: backendState,
        running: running,
        needsLogin: backendState === "NeedsLogin",
        authUrl: String(data.AuthURL || ""),
        self: self,
        fileSharing: fileSharing,
        peers: peers,
        exitNodes: exitNodes,
        exitNode: selected,
        health: Array.isArray(data.Health) ? data.Health.map(function(v) { return String(v); }) : [],
        tailnet: String((data.CurrentTailnet && (data.CurrentTailnet.Name || data.CurrentTailnet.MagicDNSSuffix)) || data.MagicDNSSuffix || "")
    };
}

function accountLabel(account) {
    return String(account.label || account.account || account.id || "");
}

function parseAccounts(raw) {
    var text = String(raw || "").trim();
    if (text === "") fail("empty accounts json");
    var data;
    try { data = JSON.parse(text); } catch (error) { fail("invalid accounts json: " + error.message); }
    if (!Array.isArray(data)) fail("accounts json must be an array");

    var result = [];
    for (var i = 0; i < data.length; i++) {
        var rawAccount = data[i];
        if (!object(rawAccount)) fail("bad account schema at " + i);
        var id = String(rawAccount.id || rawAccount.ID || "");
        if (id === "") fail("account missing id at " + i);
        var account = String(rawAccount.account || rawAccount.Account || rawAccount.loginName || rawAccount.LoginName || rawAccount.user || rawAccount.User || "");
        var label = String(rawAccount.label || rawAccount.Label || rawAccount.nickname || rawAccount.Nickname || rawAccount.name || rawAccount.Name || rawAccount.profileName || rawAccount.ProfileName || rawAccount.tailnet || rawAccount.Tailnet || account || id);
        result.push({ id: id, label: label, account: account, selected: rawAccount.selected === true || rawAccount.Selected === true || rawAccount.current === true || rawAccount.Current === true || rawAccount.active === true || rawAccount.Active === true });
    }
    return result;
}

function sliceColumn(line, start, end) {
    if (start < 0 || start >= line.length) return "";
    return (end < 0 ? line.substring(start) : line.substring(start, Math.min(end, line.length))).trim();
}

function selectedStatus(status) {
    var value = String(status || "").toLowerCase();
    return /(^|\s|[*])selected($|\s|[*])/.test(value) || /(^|\s|[*])active($|\s|[*])/.test(value);
}

function parseExitNodes(raw) {
    var lines = String(raw || "").split(/\r?\n/);
    var header = "";
    var start = -1;
    for (var i = 0; i < lines.length; i++) {
        if (/^\s*IP\s+HOSTNAME\s+COUNTRY\s+CITY\s+STATUS\s*$/.test(lines[i])) { header = lines[i]; start = i; break; }
    }
    if (start < 0) return [];

    var ipStart = header.indexOf("IP");
    var hostStart = header.indexOf("HOSTNAME");
    var countryStart = header.indexOf("COUNTRY");
    var cityStart = header.indexOf("CITY");
    var statusStart = header.indexOf("STATUS");
    var byRegion = {};

    for (var j = start + 1; j < lines.length; j++) {
        var line = lines[j];
        if (/^\s*$/.test(line) || /^\s*#/.test(line)) continue;
        var ip = sliceColumn(line, ipStart, hostStart);
        var host = sliceColumn(line, hostStart, countryStart);
        var country = sliceColumn(line, countryStart, cityStart);
        var city = sliceColumn(line, cityStart, statusStart);
        var status = sliceColumn(line, statusStart, -1);
        if (!isMullvadName(host) || country === "" || city === "" || city === "Any") continue;
        var key = country + "\n" + city;
        var selected = selectedStatus(status);
        var previous = byRegion[key];
        if (!previous || selected) {
            byRegion[key] = { id: "mullvad-region:" + key, name: city + ", " + country, target: ip || host, country: country, city: city, selected: selected || (previous ? previous.selected === true : false) };
        }
    }

    var result = [];
    for (var keyName in byRegion) result.push(byRegion[keyName]);
    result.sort(function(a, b) {
        var country = a.country.localeCompare(b.country);
        return country !== 0 ? country : a.city.localeCompare(b.city);
    });
    return result;
}

function authLink(text) {
    var match = String(text || "").match(/https?:\/\/[^\s<>'"]+/i);
    if (!match) return "";
    var url = match[0].replace(/[),.;]+$/, "");
    var authority = url.match(/^https?:\/\/([^/?#]+)/i);
    if (!authority || /[@\\\s]/.test(authority[1]) || /[\x00-\x20\\]/.test(url)) return "";
    return url;
}

function filePath(url) {
    var value = String(url || "");
    var match = value.match(/^file:\/\/(?:([^/]*))?(\/.*)$/i);
    if (!match) return "";
    var host = String(match[1] || "").toLowerCase();
    if (host !== "" && host !== "localhost") return "";
    try {
        var path = decodeURIComponent(match[2]);
        return path.indexOf("\u0000") === -1 ? path : "";
    } catch (error) { return ""; }
}

if (typeof module !== "undefined") {
    module.exports = {
        parseStatus: parseStatus,
        parseAccounts: parseAccounts,
        parseExitNodes: parseExitNodes,
        authLink: authLink,
        filePath: filePath
    };
}
