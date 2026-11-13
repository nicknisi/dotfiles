// Push upcoming calendar events, with meeting join links, to OmniWM's `fantastical` bar widget.
// OmniWM's own calendar data has no event notes, which is where Zoom/Meet links live, so this reads
// EventKit directly and sends JSON through `omniwmctl shell set meetings` (ctx.data.vars.meetings).
//
//   omniwm-calendar            push once
//   omniwm-calendar --print    print the JSON instead
//   omniwm-calendar --watch    push every minute and on calendar changes (the LaunchAgent)
//
// Built to ~/.local/bin/omniwm-calendar by the mise bootstrap hook, with an embedded Info.plist
// (Info.plist) so macOS can ask for Calendar access.
import EventKit
import Foundation

let ctl = "/Applications/OmniWM.app/Contents/MacOS/omniwmctl"
let args = Set(CommandLine.arguments.dropFirst())
let store = EKEventStore()

// Meeting services, in the order to prefer when an event links several.
let services: [(name: String, host: String, path: String)] = [
    ("Zoom", "zoom.us", "/j/"), ("Zoom", "zoom.us", "/my/"), ("Meet", "meet.google.com", "-"),
    ("Teams", "teams.microsoft.com", "/l/meetup-join"), ("Teams", "teams.live.com", "/meet"),
    ("Webex", "webex.com", "/"), ("Around", "around.co", "/"), ("Whereby", "whereby.com", "/"),
]
let urlPattern = try! NSRegularExpression(pattern: #"https?://[^\s<>"'()\[\]]+"#)

// Google Calendar wraps links in descriptions as google.com/url?q=<real link>.
func unwrap(_ url: URL) -> URL {
    guard url.host?.hasSuffix("google.com") == true, url.path == "/url",
          let q = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "q" })?.value,
          let real = URL(string: q) else { return url }
    return real
}

func links(in text: String?) -> [URL] {
    guard let text else { return [] }
    return urlPattern.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
        Range(match.range, in: text).flatMap { URL(string: String(text[$0])) }.map(unwrap)
    }
}

func join(_ event: EKEvent) -> (service: String, url: URL)? {
    let candidates = [event.url].compactMap { $0 }.map(unwrap) + links(in: event.location) + links(in: event.notes)
    for service in services {
        if let url = candidates.first(where: { $0.host?.hasSuffix(service.host) == true && $0.path.contains(service.path) }) {
            return (service.name, url)
        }
    }
    return nil
}

func hex(_ color: CGColor?) -> String {
    guard let rgb = color?.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil)?.components,
          rgb.count >= 3 else { return "#888888" }
    return String(format: "#%02X%02X%02X", Int(rgb[0] * 255), Int(rgb[1] * 255), Int(rgb[2] * 255))
}

func snapshot() -> [String: Any] {
    guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
        return ["error": "Calendar access is off for omniwm-calendar (System Settings > Privacy & Security > Calendars)."]
    }
    // Today and tomorrow only: OmniWM caps a shell var near 4 KB (see push()). Other days come from
    // OmniWM's own calendar data (`calendar day`), without join links.
    let calendar = Calendar.current
    let start = calendar.startOfDay(for: Date())
    let end = calendar.date(byAdding: .day, value: 2, to: start)!
    let events = store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: nil))
        .filter { event in !(event.attendees ?? []).contains { $0.isCurrentUser && $0.participantStatus == .declined } }
        .sorted { $0.startDate < $1.startDate }
    // The same meeting often sits on two calendars (work + personal); keep the copy with a join link.
    var seen: [String: Int] = [:], unique: [EKEvent] = []
    for event in events {
        let key = "\(event.title ?? "")|\(event.startDate.timeIntervalSince1970)|\(event.endDate.timeIntervalSince1970)"
        if let index = seen[key] {
            if join(unique[index]) == nil, join(event) != nil { unique[index] = event }
        } else {
            seen[key] = unique.count
            unique.append(event)
        }
    }
    let dayKey = DateFormatter()
    dayKey.dateFormat = "yyyy-MM-dd"
    return ["updated": Int(Date().timeIntervalSince1970), "events": unique.map { event -> [String: Any] in
        // Local days the event touches, as yyyy-MM-dd (the widget matches the selected day against these).
        var days: [String] = [], day = calendar.startOfDay(for: event.startDate)
        repeat {
            days.append(dayKey.string(from: day))
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        } while day < event.endDate && days.count < 62
        var item: [String: Any] = [
            "title": event.title ?? "", "color": hex(event.calendar.cgColor), "days": days,
            "start": Int(event.startDate.timeIntervalSince1970), "end": Int(event.endDate.timeIntervalSince1970),
            "allDay": event.isAllDay, "attendees": event.attendees?.count ?? 0,
        ]
        if let link = join(event) { item["join"] = link.url.absoluteString; item["service"] = link.service }
        // A location that is only a meeting URL adds nothing next to the Join button.
        if let location = event.location?.trimmingCharacters(in: .whitespacesAndNewlines), !location.isEmpty,
           links(in: location).isEmpty { item["location"] = location }
        if let organizer = event.organizer, !organizer.isCurrentUser, let name = organizer.name, name != "Unknown Organizer" {
            item["organizer"] = name
        }
        return item
    }]
}

// `omniwmctl shell set` rejects values over about 4 KB, so drop the latest events until it fits.
let LIMIT = 3600

func encode(_ value: [String: Any]) -> String {
    String(decoding: try! JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .withoutEscapingSlashes]), as: UTF8.self)
}

func push() {
    var value = snapshot(), json = encode(value)
    while json.utf8.count > LIMIT, var events = value["events"] as? [[String: Any]], !events.isEmpty {
        events.removeLast()
        value["events"] = events
        value["truncated"] = true
        json = encode(value)
    }
    if args.contains("--print") { print(json); return }
    let task = Process()
    task.executableURL = URL(fileURLWithPath: ctl)
    task.arguments = ["shell", "set", "meetings", json]
    task.standardOutput = FileHandle.nullDevice
    do { try task.run(); task.waitUntilExit() } catch { FileHandle.standardError.write("omniwmctl: \(error)\n".data(using: .utf8)!) }
}

store.requestFullAccessToEvents { _, _ in
    DispatchQueue.main.async {
        push()
        if !args.contains("--watch") { exit(0) }
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { _ in push() }
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in push() }
    }
}
RunLoop.main.run()
