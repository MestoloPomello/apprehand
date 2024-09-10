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
                    Spacer()
                    
                    // Mostra la lettera corrente da fare
                    if !showResult {
                        LetterDisplayView(letter: letter, viewContext: viewContext)
                    }
                                        
                    Spacer()
                    
                    if showResult {
                        VStack {
                            Spacer()
                            Image(systemName: isCorrect ? "checkmark.circle" : "x.circle")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .foregroundColor(isCorrect ? .green : .red)
                            
                            Button(action: nextLetter) {
                                Text("Prossima")
                                    .font(.title)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                        .frame(width: 300, height: 400)
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(radius: 10)
                        .padding()
                    }
                }
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

