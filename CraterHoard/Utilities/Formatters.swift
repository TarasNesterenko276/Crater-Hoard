import Foundation

/// Formatting helpers for numbers and durations shown in the interface.
enum Formatters {
    /// Formats a duration in seconds as `m:ss`.
    static func duration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// Formats a score or gold amount with grouping separators.
    static func integer(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    /// Formats a hoard height, e.g. "86 cm" or "2.4 m".
    static func height(_ centimetres: Int) -> String {
        if centimetres < 100 { return "\(centimetres) cm" }
        return oneDecimal(Double(centimetres) / 100) + " m"
    }

    /// Formats a percentage from a `0...1` fraction, e.g. "36%".
    static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }

    /// Formats a multiplier, e.g. "x1.5".
    static func multiplier(_ value: Double) -> String {
        "x" + twoDecimalsTrimmed(value)
    }

    /// One decimal place with a dot separator, trimming a trailing ".0".
    /// Locale-independent so game stats read the same everywhere.
    static func oneDecimal(_ value: Double) -> String {
        let text = String(format: "%.1f", value)
        return text.hasSuffix(".0") ? String(text.dropLast(2)) : text
    }

    /// Up to two decimals, trimming trailing zeros ("1.25", "1.5", "2").
    static func twoDecimalsTrimmed(_ value: Double) -> String {
        var text = String(format: "%.2f", value)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }

    /// Formats a date for the shift history.
    static func runDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).hour().minute())
    }
}
