import SwiftUI

struct ResultsView: View {
    @Binding var navigationPath: NavigationPath
    @State private var score: Double = 70.0 // Variabile per il punteggio, qui puoi modificarlo in base alle risposte corrette

    var body: some View {
            ZStack  {
                Image("background")
                    .resizable() // Rende l'immagine ridimensionabile
                    .scaledToFill() // Rende l'immagine adatta a riempire l'intera area
                    .ignoresSafeArea() // Fa sì che l'immagine riempia anche le aree sicure (come notch, bordi ecc.)
                VStack {
                    Text("Allenamento completato")
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
                            Text("Punteggio")
                                .font(.title)
                            Text("\(Int(score))%")
                                .font(.largeTitle)
                                .bold()
                        }
                    }
                    .frame(width: 200, height: 200)
                    
                            Button(action: {
                                navigationPath.append(Screen.levelSelectionView)
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
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        navigationPath = NavigationPath()
                        navigationPath.append(Screen.contentView)
                    }) {
                        Image(systemName: "chevron.backward")
                        Text("Indietro")
                    }
                }
            }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

