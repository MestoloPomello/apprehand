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
    @ObservedObject var navigationPath: Navigation
    var viewContext: String
    @State private var numberOfLevels: Int = 8
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 38) {
                    HStack {
                        Button(action: {
                            navigateToRoot()
                        }) {
                            Image(systemName: "chevron.backward")
                            Text("Indietro")
                        }
                        .padding(.leading)
                        Spacer()
                    }
                    
                    ForEach(0..<(numberOfLevels / 2), id: \.self) { i in
                        HStack(spacing: 23) {
                            CustomButton_Level(
                                lvNumber: (i * 2) + 1,
                                context: viewContext,
                                gradientColors: gradientsForContext[viewContext]?.colori ?? [Color.white, Color.gray],
                                navigationPath: $navigationPath.path
                            )
                            CustomButton_Level(
                                lvNumber: (i * 2) + 2,
                                context: viewContext,
                                gradientColors: gradientsForContext[viewContext]?.colori ?? [Color.white, Color.gray],
                                navigationPath: $navigationPath.path
                            )
                        }
                    }
                }
                .padding(.top, 38)
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
    }
    
    private func navigateToRoot() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController = UIHostingController(rootView: ContentView())
            window.makeKeyAndVisible()
        }
    }
}

struct CustomButton_Level: View {
    var lvNumber: Int
    var context: String
    var gradientColors: [Color]
    @Binding var navigationPath: [Screen]
    
    var body: some View {
        Button(action: {
            navigationPath.append(Screen.cameraOverlayView(lvNumber, context))
            //navigationPath.append(Screen.resultsView(lvNumber))
        }) {
            VStack {
                Text("Livello")
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
                        Image("star_yellow")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 27, height: 27)
                    }
                }
                .padding(.top, 20)
            }
            .frame(width: 162, height: 250)
            .background(
                LinearGradient(gradient: Gradient(colors: gradientColors), startPoint: .top, endPoint: .bottom)
            )
            .cornerRadius(15)
            .shadow(color: gradientsForContext[context]!.ombra, radius: 0, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }
}
