import SwiftUI

struct ResultsView: View {
    @ObservedObject var navigationPath: Navigation
    @State var score: Double = 70.0
    
    let gradientData = gradientsForContext["allenati"]!

    var TRANSLATED_TEXT: [String: String] = getTranslatedText()    

    var body: some View {
        ZStack {
            Image("background_plain")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            VStack {
                Text(TRANSLATED_TEXT["training_completed"])
                    .multilineTextAlignment(.center)
                    .padding(.top, 102)
                    .font(.system(size: 40))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .shadow(
                        color: Color.black.opacity(0.2),
                        radius: 4,
                        x: 0,
                        y: 4
                    )
                
                Spacer()
                    .frame(height: 130)

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
                    
                    VStack {
                        Text("Punteggio")
                        .font(.system(size: 20))
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        Text("\(Int(score))%")
                            .font(.system(size: 40))
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                    }
                }
                .frame(width: 249, height: 249)
                
                Button(action: {
                    navigateToRoot()
                }) {
                    Text("Menu")
                        .font(.title) // Modifica la dimensione del testo
                        .padding() // Spazio interno del bottone
                        .frame(width: 182, height: 88) // Dimensione del bottone
                        .background(LinearGradient(gradient: Gradient(colors: gradientData.colori), startPoint: .top, endPoint: .bottom))
                        .foregroundColor(.white)
                        .cornerRadius(15)
                        
                }
                .padding(.top, 70)
                
                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private func navigateToRoot() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController = UIHostingController(rootView: LevelSelectionView(navigationPath: navigationPath, viewContext: "allenati"))
            window.makeKeyAndVisible()
        }
    }
}
