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
    @Binding var navigationPath: NavigationPath
    var viewContext: String
    @State private var numberOfLevels: Int = 8
    
    var body: some View {
        //NavigationView {
        ZStack {
            Color.white.ignoresSafeArea()
            
            ScrollView {
                ZStack {
                    VStack(spacing: 38) {
                        HStack {
                            Button(action: {
                                /*if navigationPath.count > 1 {
                                    navigationPath.removeLast()
                                }
                                navigationPath.append(Screen.contentView)*/
                                navigationPath = NavigationPath()
                                navigationPath.append(Screen.contentView)
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
                                    navigationPath: $navigationPath
                                )
                                CustomButton_Level(
                                    lvNumber: (i * 2) + 2,
                                    context: viewContext,
                                    gradientColors: gradientsForContext[viewContext]?.colori ?? [Color.white, Color.gray],
                                    navigationPath: $navigationPath
                                )
                            }
                        }
                    }
                    .padding(.top, 38)
                    /*.toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: {
                                navigationPath = NavigationPath()
                                navigationPath.append(Screen.contentView)
                            }) {
                                Image(systemName: "chevron.backward")
                                Text("Indietro")
                            }
                        }
                    }*/
                }
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .navigationDestination(for: Screen.self) { screen in
            switch screen {
            case .cameraOverlayView(let level, let context):
                // CameraOverlayView(navigationPath: $navigationPath, viewContext: viewContext)
                ResultsView(navigationPath: $navigationPath, score: 50.0)
            case .contentView:
                ContentView()
            case .levelSelectionView(let context):
                LevelSelectionView(navigationPath: $navigationPath, viewContext: context)
            case .resultsView:
                ResultsView(navigationPath: $navigationPath)
            }
        }
    }
}

struct CustomButton_Level: View {
    var lvNumber: Int
    var context: String
    var gradientColors: [Color]
    @Binding var navigationPath: NavigationPath
    
    var body: some View {
        Button(action: {
            navigationPath.append(Screen.cameraOverlayView(lvNumber, context))
        }) {
            //NavigationLink(destination: CameraOverlayView(lvNumber: lvNumber, viewContext: context)) {
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
            //}
        }
        .buttonStyle(.plain)
    }
}

/*struct LevelSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        LevelSelectionView(
            navigationPath: nil, viewContext: "impara"
        )
    }
}*/