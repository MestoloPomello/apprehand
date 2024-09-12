import SwiftUI

enum Screen: Hashable {
    case resultsView(Int)
    case levelSelectionView(String)
    case contentView
    case cameraOverlayView(Int, String)
}

class Navigation: ObservableObject {
    @Published var path = [Screen]()
}

class NavigationController {
    @ViewBuilder
    static func navigate(to screen: Screen, with navigation: Navigation) -> some View {
        switch screen {
        case .contentView:
            ContentView()
        case .levelSelectionView("impara"):
            //LevelSelectionView(navigationPath: navigation, viewContext: "impara")
            LevelSelectionView(viewContext: "impara", navigationPath: navigation)
        case .levelSelectionView("allenati"):
            //LevelSelectionView(navigationPath: navigation,                viewContext: "allenati")
            LevelSelectionView(viewContext: "allenati", navigationPath: navigation)
        case .resultsView:
            ResultsView(navigationPath: navigation)
        default :
            ContentView()
}
    }
}

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

let gradientsForContext: [String: GradientData] = [
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

let lettersLevels: [Int: [String]] = [
    1: ["a"],
    2: ["b", "c"],
    3: ["d", "e"],
    4: ["f", "h", "i"],
    5: ["k", "l", "m"],
    6: ["n", "o", "p"],
    7: ["q", "r", "t", "u"],
    8: ["v", "w", "x", "y"]
]

//let defaults = UserDefaults.standard
/*func getTranslatedText() -> [String: String] {
    switch(defaults.string(forKey: "language")) {
        case "english":
            return EN_TRANSLATED_TEXT
        case "french":
            return FR_TRANSLATED_TEXT
        case "spanish":
            return ES_TRANSLATED_TEXT
        default:
            return IT_TRANSLATED_TEXT
    }
}*/

func getTranslatedString(key: String) -> String {
    switch(UserDefaults.standard.string(forKey: "language")) {
        case "english":
            return EN_TRANSLATED_TEXT[key]!
        case "french":
            return FR_TRANSLATED_TEXT[key]!
        case "spanish":
            return ES_TRANSLATED_TEXT[key]!
        default:
            return IT_TRANSLATED_TEXT[key]!
    }
}


// Border management

struct EdgeBorder: Shape {
    var width: CGFloat
    var edges: [Edge]

    func path(in rect: CGRect) -> Path {
        edges.map { edge -> Path in
            switch edge {
            case .top: return Path(.init(x: rect.minX, y: rect.minY, width: rect.width, height: width))
            case .bottom: return Path(.init(x: rect.minX, y: rect.maxY - width, width: rect.width, height: width))
            case .leading: return Path(.init(x: rect.minX, y: rect.minY, width: width, height: rect.height))
            case .trailing: return Path(.init(x: rect.maxX - width, y: rect.minY, width: width, height: rect.height))
            }
        }.reduce(into: Path()) { $0.addPath($1) }
    }
}

extension View {
    func border(width: CGFloat, edges: [Edge], color: Color) -> some View {
        overlay(EdgeBorder(width: width, edges: edges).foregroundColor(color))
    }
}


func navigateToView(rootView: some View) {
    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
       let window = windowScene.windows.first {
        window.rootViewController = UIHostingController(rootView: rootView)
        window.makeKeyAndVisible()
    }
}
