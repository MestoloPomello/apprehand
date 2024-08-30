import SwiftUI

struct ResultsView: View {
    @Binding var navigationPath: NavigationPath
    @State var score: Double = 70.0 // Variabile per il punteggio, qui puoi modificarlo in base alle risposte corrette

    var body: some View {
            ZStack  {
                Image("background")
                    .resizable() // Rende l'immagine ridimensionabile
                    .scaledToFill() // Rende l'immagine adatta a riempire l'intera area
                    .ignoresSafeArea() // Fa sì che l'immagine riempia anche le aree sicure (come notch, bordi ecc.)
                VStack {
                    Text(TRANSLATED_TEXT["training_completed"])
                        .font(.largeTitle)
                        .padding()
                    
                    ZStack {
                        Circle()
                            .stroke(lineWidth: 20)
                            .opacity(0.3)
                            .foregroundColor(.gray)
                        
                        Circle()
                            .trim(from: 0.0, to: CGFloat(min(self.score / 100, 1.0)))
                            .stroke(style: StrokeStyle(lineWidth: 20, lineCap: .round, lineJoin: .round))
                            .foregroundColor(.green)
                            .rotationEffect(Angle(degrees: 270.0))
                        //	.animation(.linear)
                        
                        VStack {
                            Text(TRANSLATED_TEXT["score"])
                                .font(.title)
                            Text("\(Int(score))%")
                                .font(.largeTitle)
                                .bold()
                        }
                    }
                    .frame(width: 200, height: 200)
                    
                            Button(action: {
                                // if navigationPath.count > 1 {
                                //     navigationPath.removeLast()
                                // }
                                navigationPath = NavigationPath()
                                navigationPath.append(Screen.levelSelectionView("allenati"))
                            }) {
                                Text("Menu")
                                    .font(.title)
                                    .padding()
                                    .frame(width: 200)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .padding(.top, 50)
                    Spacer()
                }
            }
            .navigationBarBackButtonHidden(true)
            .navigationDestination(for: Screen.self) { screen in
                switch screen {
                case .levelSelectionView(let context):
                    LevelSelectionView(navigationPath: $navigationPath, viewContext: context)
                case .contentView:
                    ContentView()
                case .resultsView:
                    ResultsView(navigationPath: $navigationPath, score: 0.00)
                case .cameraOverlayView:
                    CameraOverlayView(navigationPath: $navigationPath, lvNumber: lvNumber, viewContext: "impara")
                }
            }
            // .toolbar {
            //     ToolbarItem(placement: .navigationBarLeading) {
            //         Button(action: {
            //             if navigationPath.count > 1 {
            //                 navigationPath.removeLast()
            //             }
            //             navigationPath.append(Screen.contentView)
            //         }) {
            //             Image(systemName: "chevron.backward")
            //             Text("Indietro")
            //         }
            //     }
            // }
            
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

