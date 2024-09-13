import SwiftUI

var starsForDiff = [
    1: 1,
    2: 1,
    3: 1,
    4: 2,
    5: 2,
    6: 2,
    7: 3,
    8: 3
]


struct LevelSelectionView: View {
    var viewContext: String
    @State private var numberOfLevels: Int = 8
    @StateObject var navigationPath = Navigation()

    var body: some View {
        let progress: Int = UserDefaults.standard.integer(forKey: "progress_\(viewContext)")
        
        NavigationStack(path: $navigationPath.path) {
            ZStack {
                Color.white.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 38) {
                        HStack {
                            Button(action: {
                                navigateToView(rootView: ContentView())
                            }) {
                                Image(systemName: "chevron.backward")
                                Text("Indietro")
                            }
                            .padding(.leading)
                            Spacer()
                        }
                        
                        ForEach(0..<((Int)(numberOfLevels) / (Int)(2)), id: \.self) { i in
                            let lvNumber1: Int = (i * 2) + 1
                            let lvNumber2: Int = (i * 2) + 2
                            HStack(spacing: 23) {
                                CustomButton_Level(
                                    lvNumber: lvNumber1,
                                    context: viewContext,
                                    gradientColors: (lvNumber1 <= (progress + 1)) ? gradientsForContext[viewContext]!.colori : gradientsForContext["locked"]!.colori,
                                    progress: progress
                                ) {
                                    if lvNumber1 <= (progress + 1) {
                                        navigateToView(rootView: CameraOverlayView(lvNumber: lvNumber1, viewContext: viewContext))
                                    } 
                                }
                                CustomButton_Level(
                                    lvNumber: lvNumber2,
                                    context: viewContext,
                                    gradientColors: (lvNumber2 <= (progress + 1))
                                        ? gradientsForContext[viewContext]!.colori
                                        : gradientsForContext["locked"]!.colori,
                                    progress: progress
                                ) {
                                    if lvNumber2 <= (progress + 1) {
                                        navigateToView(rootView: CameraOverlayView(lvNumber: lvNumber2, viewContext: viewContext))
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, 38)
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .navigationBarBackButtonHidden(true)
            .navigationDestination(for: Screen.self) { screen in
                NavigationController.navigate(to: screen, with: navigationPath)
            }
        }
        .environmentObject(navigationPath)
    }
}


struct CustomButton_Level: View {
    var lvNumber: Int
    var context: String
    var gradientColors: [Color]
    var progress: Int
    var action: () -> Void
    
    var body: some View {
        
        Button(action: action) {
            VStack {
                Text(getTranslatedString(key: "level"))
                    .font(.system(size: 25))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .shadow(
                        color: Color.black.opacity(0.2),
                        radius: 4,
                        x: 0,
                        y: 4
                    )
                Text("\(lvNumber)")
                    .font(.system(size: 70))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.bottom, 20)
                    .shadow(
                        color: Color.black.opacity(0.2),
                        radius: 4,
                        x: 0,
                        y: 4
                    )
                HStack (spacing: 13) {
                    ForEach(0..<(starsForDiff[lvNumber] ?? 0), id: \.self) { _ in
                        if lvNumber <= (progress + 1) {
                            Image("star_yellow")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 27, height: 27)
                        } else {
                            Image("star_black")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 27, height: 27)
                        } 
                    }
                }
                .padding(.top, 20)
            }
            .frame(width: 162, height: 250)
            .background(
                LinearGradient(gradient: Gradient(colors: gradientColors), startPoint: .top, endPoint: .bottom)
            )
            .cornerRadius(15)
            .shadow(
                color: (lvNumber <= (progress + 1))
                    ? gradientsForContext[context]!.ombra
                    : gradientsForContext["locked"]!.ombra,
                radius: 0,
                x: 0,
                y: 5
            )
        }
        .buttonStyle(.plain)
    }
}
