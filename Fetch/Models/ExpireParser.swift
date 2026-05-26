import Foundation

enum ExpireParser {
    /// Parse a human-typed expire string.
    /// Accepts `YYYY-MM-DD`, `YYYY/MM/DD`, and `+Nd` (N days from now).
    /// Empty / whitespace string returns `.success(nil)` to clear the value.
    /// Returns `.failure` for unparseable input so callers can keep the
    /// previous value and surface an error if needed.
    static func parse(_ raw: String, now: Date = Date(), calendar: Calendar = .current)
        -> Result<Date?, ParseError>
    {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .success(nil) }

        // +Nd
        if trimmed.first == "+", trimmed.hasSuffix("d"),
           let n = Int(trimmed.dropFirst().dropLast()),
           let date = calendar.date(byAdding: .day, value: n, to: calendar.startOfDay(for: now))
        {
            return .success(date)
        }

        for format in ["yyyy-MM-dd", "yyyy/MM/dd"] {
            let df = DateFormatter()
            df.calendar = calendar
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = calendar.timeZone
            df.dateFormat = format
            if let d = df.date(from: trimmed) { return .success(d) }
        }

        return .failure(.unparseable)
    }

    /// Stable canonical text shown when the user starts editing this field.
    /// Always `YYYY-MM-DD` so re-editing round-trips cleanly.
    static func format(_ date: Date, calendar: Calendar = .current) -> String {
        let df = DateFormatter()
        df.calendar = calendar
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = calendar.timeZone
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: date)
    }

    /// Short label for the badge in browse mode. `MM/DD` when far away,
    /// `Nd` when within a week, `expired` once past.
    static func badge(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTarget = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: startOfToday, to: startOfTarget).day ?? 0
        if days < 0 { return "expired" }
        if days == 0 { return "today" }
        if days <= 7 { return "\(days)d" }
        let df = DateFormatter()
        df.calendar = calendar
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = calendar.timeZone
        df.dateFormat = "MM/dd"
        return df.string(from: date)
    }

    enum Status { case expired, soon, ok }

    static func status(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> Status {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTarget = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: startOfToday, to: startOfTarget).day ?? 0
        if days < 0 { return .expired }
        if days <= 7 { return .soon }
        return .ok
    }

    enum ParseError: Error { case unparseable }
}
