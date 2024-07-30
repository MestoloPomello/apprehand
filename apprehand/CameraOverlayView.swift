import SwiftUI
import AVFoundation
import CoreML
import Vision

struct CameraView: UIViewControllerRepresentable {
    class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        var parent: CameraView
        var model: VNCoreMLModel
        var request: VNCoreMLRequest
        var bufferSize: CGSize = .zero
        var rootLayer: CALayer! = nil
        var detectionOverlay: CALayer! = nil
        
        init(parent: CameraView) {
            self.parent = parent
            guard let model = try? VNCoreMLModel(for: YourMLModel().model) else {   // YourMLModel da sostituire con modello vero
                fatalError("Failed to load model")
            }
            self.model = model
            self.request = VNCoreMLRequest(model: model, completionHandler: self.handleRequest)
            self.request.imageCropAndScaleOption = .scaleFill
        }
        
        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
            do {
                try handler.perform([self.request])
            } catch {
                print(error)
            }
        }
        
        func handleRequest(request: VNRequest, error: Error?) {
            guard let results = request.results as? [VNClassificationObservation] else { return }
            if let bestResult = results.first {
                DispatchQueue.main.async {
                    self.parent.handlePrediction(prediction: bestResult.identifier)
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo
        
        guard let videoCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else { return viewController }
        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return viewController
        }

        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else {
            return viewController
        }

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(context.coordinator, queue: DispatchQueue(label: "videoQueue"))
        if (captureSession.canAddOutput(videoOutput)) {
            captureSession.addOutput(videoOutput)
        } else {
            return viewController
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = viewController.view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        viewController.view.layer.addSublayer(previewLayer)
        
        captureSession.startRunning()
        
        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Aggiorna la UI del view controller se necessario
    }

    func handlePrediction(prediction: String) {
        // Implementa la gestione delle previsioni qui
    }
}

struct CameraOverlayView: View {
    @State private var currentLetterIndex: Int = 0
    @State private var showResult: Bool = false
    @State private var isCorrect: Bool = false
    @State private var letter: String = ""
    
    var lvNumber: Int
    var viewContext: String
    
    var body: some View {
        let letters = lettersLevels[lvNumber] ?? []
        
        ZStack {
            CameraView()
                .edgesIgnoringSafeArea(.all)
                .onAppear {
                    letter = letters[currentLetterIndex]
                }
            
            if showResult {
                VStack {
                    Spacer()
                    Image(systemName: isCorrect ? "checkmark.circle" : "x.circle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                    
                    if isCorrect {
                        Button(action: nextLetter) {
                            Text("Prossima")
                                .font(.title)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    } else {
                        VStack(spacing: 10) {
                            Button(action: nextLetter) {
                                Text("Prossima")
                                    .font(.title)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            Button(action: retry) {
                                Text("Riprova")
                                    .font(.title)
                                    .padding()
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
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
    
    func handlePrediction(prediction: String) {
        if prediction == letter {
            isCorrect = true
            showResult = true
        } else {
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
            // Fine livello, torna alla view di selezione del livello
            // Implementa il codice per tornare alla view di selezione del livello
        }
    }
    
    func retry() {
        showResult = false
    }
}

struct CameraOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        CameraOverlayView(lvNumber: 1, viewContext: "impara")
    }
}
