import SwiftUI

/// Visual language of Crater Hoard: cave copper and patina over charcoal basalt,
/// with cream assay paper for readable panels.
enum Theme {
    enum Colors {
        static let basalt = Color(red: 0.09, green: 0.08, blue: 0.10)
        static let charcoal = Color(red: 0.15, green: 0.12, blue: 0.13)
        static let copper = Color(red: 0.78, green: 0.45, blue: 0.23)
        static let copperDark = Color(red: 0.46, green: 0.24, blue: 0.11)
        static let copperLight = Color(red: 0.93, green: 0.64, blue: 0.40)
        static let patina = Color(red: 0.31, green: 0.70, blue: 0.63)
        static let patinaDark = Color(red: 0.13, green: 0.42, blue: 0.38)
        static let gold = Color(red: 0.91, green: 0.72, blue: 0.29)
        static let goldLight = Color(red: 0.97, green: 0.85, blue: 0.54)
        static let paper = Color(red: 0.95, green: 0.90, blue: 0.80)
        static let paperShade = Color(red: 0.87, green: 0.79, blue: 0.64)
        /// Text colour on paper (contrast ≥ 10:1 against `paper`).
        static let ink = Color(red: 0.17, green: 0.11, blue: 0.09)
        static let inkSoft = Color(red: 0.36, green: 0.26, blue: 0.21)
        static let lava = Color(red: 1.0, green: 0.42, blue: 0.16)
        static let lavaHot = Color(red: 1.0, green: 0.78, blue: 0.30)
        static let danger = Color(red: 0.72, green: 0.20, blue: 0.13)
        static let chalk = Color(red: 0.94, green: 0.94, blue: 0.90)
        static let slate = Color(red: 0.16, green: 0.19, blue: 0.20)
    }

    enum Metrics {
        static let maxContentWidth: CGFloat = 560
        static let corner: CGFloat = 16
        static let minimumTap: CGFloat = 44
    }
}

extension Font {
    /// Slab-serif display face used for titles, numbers and buttons.
    static func display(_ size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font {
        .custom("Rockwell-Bold", size: size, relativeTo: style)
    }

    /// Humanist body face for descriptions and labels.
    static func body(_ size: CGFloat, relativeTo style: Font.TextStyle = .body, bold: Bool = false) -> Font {
        .custom(bold ? "GillSans-SemiBold" : "GillSans", size: size, relativeTo: style)
    }
}
