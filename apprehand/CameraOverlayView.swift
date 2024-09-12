import SwiftUI
import AVFoundation
import CoreML
import Vision

struct CameraOverlayView: View {
    @StateObject var navigationPath = Navigation()
    @State private var currentLetterIndex: Int = 0
    @State private var showResult: Bool = false
    @State private var isCorrect: Bool = false
    @State private var letter: String = ""
    @State private var prediction: String = ""
    @State private var rightGuesses: Int = 0
    @State private var imgSrc: String = ""
    
    var lvNumber: Int
    var viewContext: String
    
    var body: some View {
        let letters = lettersLevels[lvNumber] ?? []
        NavigationStack(path: $navigationPath.path) {
            ZStack {
                CameraView(showResult: $showResult)
                //.edgesIgnoringSafeArea(.all)
                    .onAppear {
                        letter = letters[currentLetterIndex]
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .predictionDidUpdate)) { notification in
                        if let prediction = notification.object as? String {
                            handlePrediction(prediction: prediction)
                            print("Ricevuto prediction da CameraOverlayView", prediction)
                        }
                    }
                
                if showResult {
                    Rectangle()
                        .fill(Color(hex: 0x000000, opacity: 0.3))
                        .edgesIgnoringSafeArea(.all)
                }
                
                VStack {
                    HStack {
                        Button(action: {
                            navigateToView(rootView: LevelSelectionView(viewContext: viewContext))
                        }) {
                            Image(systemName: "chevron.backward")
                            Text("Indietro")
                        }
                        .padding(.leading)
                        Spacer()
                    }
                    
                    // Mostra la lettera corrente da fare
                    if !showResult {
                        LetterDisplayView(letter: letter, viewContext: viewContext)
                    }
                    
                    if showResult {
                        Spacer()
                        VStack(alignment: .center, spacing: 34) {
                            Image(isCorrect ? "cerchio_giusto_\(viewContext)" : "cerchio_sbagliato_\(viewContext)")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 206, height: 206)
                            //.foregroundColor(isCorrect ? .green : .red)
                            
                            CustomButton_CameraOverlay(
                                title: "Prossima",
                                gradientColors: viewContext == "allenati" ? [Color(hex: 0xbae4fc), Color(hex: 0x3fabd9)] : [Color(hex: 0xd7dbfc), Color(hex: 0x8785f2)],
                                shadowColor: viewContext == "allenati" ? Color(hex: 0x277099) : Color(hex: 0x4c3fe4),
                                action: nextLetter
                            )
                            
                            if viewContext == "impara" && !isCorrect {
                                Divider()
                                
                                CustomButton_CameraOverlay(
                                    title: "Riprova",
                                    gradientColors: [Color(hex: 0xebcdec), Color(hex: 0xba78c0)],
                                    shadowColor: Color(hex: 0x754376),
                                    action: { showResult = false }
                                )
                            }
                        }
                        .frame(width: 344, height: 558)
                        .background(Color.white)
                        .cornerRadius(15)
                        .shadow(
                            color: Color.black.opacity(0.5),
                            radius: 4,
                            x: 0,
                            y: 4
                        )
                        .padding(34)
                        
                        Spacer()
                    }
                }
                .padding(10)
            }
            .navigationDestination(for: Screen.self) { screen in
                NavigationController.navigate(to: screen, with: navigationPath)
            }
        }
        //.environmentObject(navigationPath)
    }
    
    func handlePrediction(prediction: String) {
        if prediction == letter {
            isCorrect = true
            rightGuesses += 1
            showResult = true
        } else if prediction != "" {
            isCorrect = false
            showResult = true
        }
    }
    
    func nextLetter() {
        showResult = false
        if currentLetterIndex + 1 < lettersLevels[lvNumber]!.count {
            currentLetterIndex += 1
            letter = lettersLevels[lvNumber]![currentLetterIndex]
        } else {
            // Calcola il punteggio finale e naviga alla ResultsView
            let score = Double(rightGuesses) / Double(lettersLevels[lvNumber]!.count) * 100
            navigationPath.path.append(.resultsView(Int(score)))
        }
    }
}


struct LetterDisplayView: View {
    //var letterImage: Image
    var letter: String
    var viewContext: String
    
    var body: some View {
        
        VStack (alignment: .trailing, spacing: 100) {
            Spacer()
            HStack {
                
                // {}
                
                Spacer().frame(width: 21)
                
                ZStack {
                    Rectangle()
                        .fill(Color(hex: 0xAFB0F7, opacity: 0.5))
                        .border(Color(hex: 0xC5C5C5), width: 1)
                        .frame(width: 130, height: 130)
                        .cornerRadius(15)
                    
                    if viewContext == "allenati" {
                        Image("punti_domanda")
                            .scaledToFit()
                            .frame(width: 84, height: 84)
                            .padding()
                            .cornerRadius(15)
                    } else {
                        //Image("hand_sign_\(letter)")
                        Image("Esempio")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 84, height: 84)
                            .padding()
                            .cornerRadius(15)
                    }
                }
                
                Spacer().frame(width: 20)
                
                ZStack() {
                    Rectangle()
                        .fill(Color(hex: 0xDEDEDE, opacity: 0.2))
                        .border(width: 1, edges: [.leading], color: Color(hex: 0xC5C5C5))
                    
                    // Parte destra: Testo che mostra la lettera
                    VStack(alignment: .center) {
                        Text("Lettera")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.black)
                        Text(letter)
                            .textCase(.uppercase)
                            .font(.system(size: 70, weight: .bold))
                            .foregroundColor(.black)
                    }
                    .frame(width: 130, height: 130)
                }
            }
            .frame(height: 167)
            .background(Color.white)
            .cornerRadius(15)
            .shadow(radius: 5)
            .padding([.leading, .trailing], 25)
        }
    }
}



// Estensione per le notifiche
extension Notification.Name {
    static let predictionDidUpdate = Notification.Name("predictionDidUpdate")
}


struct CustomButton_CameraOverlay: View {
    var title: String
    var gradientColors: [Color]
    var shadowColor: Color
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Text(title)
                    .font(.system(size: 25))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                //.padding(.bottom, 20)
                    .shadow(
                        color: Color.black.opacity(0.2),
                        radius: 4,
                        x: 0,
                        y: 4
                    )
            }
            .frame(width: 182, height: 88)
            .background(
                LinearGradient(gradient: Gradient(colors: gradientColors), startPoint: .top, endPoint: .bottom)
            )
            .cornerRadius(15)
            .shadow(color: shadowColor, radius: 0, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }
}
