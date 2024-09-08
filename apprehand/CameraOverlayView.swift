import SwiftUI
import AVFoundation
import CoreML
import Vision

struct CameraOverlayView: View {
    @EnvironmentObject var navigationPath: Navigation
    @State private var currentLetterIndex: Int = 0
    @State private var showResult: Bool = false
    @State private var isCorrect: Bool = false
    @State private var letter: String = ""
    @State private var prediction: String = ""
    @State private var rightGuesses: Int = 0
    @State private var imgSrc: String = ""
    
    var TRANSLATED_TEXT: [String: String] = getTranslatedText()
    
    var lvNumber: Int
    var viewContext: String
    
    var body: some View {
        let letters = lettersLevels[lvNumber] ?? []
        NavigationStack(path: $navigationPath.path) {
            ZStack {
                CameraView(showResult: $showResult)
                    .edgesIgnoringSafeArea(.all)
                    .onAppear {
                        print("CameraOverlayView è apparso")
                        letter = letters[currentLetterIndex]
                    }
                    .onDisappear {
                        print("CameraOverlayView è scomparso")
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
                    LetterDisplayView(letterImage: Image("hand_sign_e"), letter: letter)
                    
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
    var letterImage: Image
    var letter: String
    
    var body: some View {
        HStack {
            // Parte sinistra: immagine del segno della lettera
            letterImage
                .resizable()
                .scaledToFit()
                .frame(width: 130, height: 130)
                .padding()
                .background(Color(red: 0.9, green: 0.9, blue: 1.0)) // Colore simile allo sfondo viola chiaro
                .cornerRadius(15)
            
            // Parte destra: Testo che mostra la lettera
            VStack(alignment: .leading) {
                Text("Lettera")
                    .font(.headline)
                    .foregroundColor(.black)
                Text(letter)
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(.black)
            }
            .padding()
        }
        .background(Color.white)
        .cornerRadius(15)
        .shadow(radius: 5)
        .padding()
    }
}



// Estensione per le notifiche
extension Notification.Name {
    static let predictionDidUpdate = Notification.Name("predictionDidUpdate")
}

