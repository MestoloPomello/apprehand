import SwiftUI

extension Color {
    init(hex: Int, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: opacity
        )
    }
}

struct GradientData {
    var colori: [Color]
    var ombra: Color
}

var gradientsForContext: [String: GradientData] = [
    "impara": GradientData(
        colori: [Color(hex: 0xd7dbfc), Color(hex: 0x8785f2)],
        ombra: Color(hex: 0x4c3fe4)
    ),
    "allenati": GradientData(
        colori: [Color(hex: 0xbae4fc), Color(hex: 0x3fabd9)],
        ombra: Color(hex: 0x277099)
    ),
    "locked": GradientData(
        colori: [Color(hex: 0xe5e5e5), Color(hex: 0xa6a6a6)],
        ombra: Color(hex: 0x727272)
    )
]

var lettersLevels: [Int: [String]] = [
    1: ["a"],
    2: ["b", "c"],
    3: ["d", "e"],
    4: ["f", "h", "i"],
    5: ["k", "l", "m"],
    6: ["n", "o", "p"],
    7: ["q", "r", "t", "u"],
    8: ["v", "w", "x", "y"]
]