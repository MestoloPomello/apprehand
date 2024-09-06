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
    
    var TRANSLATED_TEXT: [String: String] = getTranslatedText()    

    var lvNumber: Int
    var viewContext: String
    
    var body: some View {
        let letters = lettersLevels[lvNumber] ?? []
        
        ZStack {
            CameraView(showResult: $showResult)
                .edgesIgnoringSafeArea(.all)
                .onAppear {
                    letter = letters[currentLetterIndex]
                }
                .onReceive(NotificationCenter.default.publisher(for: .predictionDidUpdate)) { notification in
                    if let prediction = notification.object as? String {
                        handlePrediction(prediction: prediction)
                        print("Ricevuto prediction da CameraOverlayView", prediction)
                    }
                }
            
            VStack {
                Spacer()
                
                // Mostra la lettera corrente da fare
                VStack {
                    Text("Fai questa lettera:")
                        .font(.title)
                    Text(letter)
                        .font(.largeTitle)
                        .bold()
                    Image(systemName: "\(letter).circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                }
                .padding()
                .background(Color.white.opacity(0.7))
                .cornerRadius(15)
                
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


// Estensione per le notifiche
extension Notification.Name {
    static let predictionDidUpdate = Notification.Name("predictionDidUpdate")
}

