
import SwiftUI
import AVFoundation
import CoreML
import Vision
import CoreImage

// CameraView per gestire la cattura video
struct CameraView: UIViewControllerRepresentable {
    
    @Binding var showResult: Bool
    
    class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        var isShowingResult: Bool = false
        var parent: CameraView
        var model: VNCoreMLModel?
        var request: VNDetectHumanHandPoseRequest?
        
        weak private var previewView: UIView!
        var bufferSize: CGSize = .zero
        var rootLayer: CALayer! = nil
        private let videoDataOutput = AVCaptureVideoDataOutput()
        private let session = AVCaptureSession()
        private var previewLayer: AVCaptureVideoPreviewLayer! = nil
        private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
        
        private var predictions: [String] = []
        private var predictionTimer: Timer?
        
        init(parent: CameraView) {
            self.parent = parent
            super.init()
            setupVisionRequest()
        }
        
        func setupVisionRequest() {
            // Creiamo la richiesta per l'hand pose
            let handPoseRequest = VNDetectHumanHandPoseRequest()
            handPoseRequest.maximumHandCount = 1
            self.request = handPoseRequest
        }
        
        func handlePrediction(keypoints: [CGPoint]) {
            var inputArray: [Double] = []
            for point in keypoints {
                inputArray.append(point.x)
                inputArray.append(point.y)
            }
            
            // Crea l'input personalizzato
            let customInput = CustomModelInput(keypoints: inputArray)
            
            // Assicurati di avere esattamente 42 valori
            guard inputArray.count == 42 else {
                print("Errore: numero di valori di input errato")
                return
            }
            
            // Passiamo i keypoints al modello CoreML
            guard let model = try? apprehandTabularClassifier2(configuration: MLModelConfiguration()) else {
                fatalError("Impossibile caricare il modello CoreML")
            }
            
            // Crea input per il modello
            guard let prediction = try? model.prediction(x0: inputArray[0], y0: inputArray[1], x1: inputArray[2], y1: inputArray[3], x2: inputArray[4], y2: inputArray[5], x3: inputArray[6], y3: inputArray[7], x4: inputArray[8], y4: inputArray[9], x5: inputArray[10], y5: inputArray[11], x6: inputArray[12], y6: inputArray[13], x7: inputArray[14], y7: inputArray[15], x8: inputArray[16], y8: inputArray[17], x9: inputArray[18], y9: inputArray[19], x10: inputArray[20], y10: inputArray[21], x11: inputArray[22], y11: inputArray[23], x12: inputArray[24], y12: inputArray[25], x13: inputArray[26], y13: inputArray[27], x14: inputArray[28], y14: inputArray[29], x15: inputArray[30], y15: inputArray[31], x16: inputArray[32], y16: inputArray[33], x17: inputArray[34], y17: inputArray[35], x18: inputArray[36], y18: inputArray[37], x19: inputArray[38], y19: inputArray[39], x20: inputArray[40], y20: inputArray[41]) else {
                print("Errore durante la previsione")
                return
            }
            
            let predictedLetter = prediction.label
            
            print("predictedLetter", predictedLetter)
            
            // Salva la predizione
            predictions.append(predictedLetter)
            
            // Se non è in corso una rilevazione, avvia il timer
            if predictionTimer == nil {
                predictionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                    self.handlePredictions()
                }
            }
        }
        
        private func handlePredictions() {
            // Conta le occorrenze delle predizioni
            let count = predictions.reduce(into: [String: Int]()) { counts, prediction in
                counts[prediction, default: 0] += 1
            }
            
            // Trova la lettera più gettonata
            let mostFrequentLetter = count.max { $0.value < $1.value }?.key
            
            // Usa la lettera più gettonata
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .predictionDidUpdate, object: mostFrequentLetter)
            }
            
            // Pulisci le predizioni e il timer
            predictions.removeAll()
            predictionTimer?.invalidate()
            predictionTimer = nil
        }
        
        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            
            if isShowingResult {
                return
            }
            
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            let exifOrientation = exifOrientationFromDeviceOrientation()
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: [:])
            
            do {
                try imageRequestHandler.perform([self.request!])
                if let handPoseRequest = self.request, let results = handPoseRequest.results?.first {
                    // Estrarre i keypoints dalla mano
                    let handLandmarks = try results.recognizedPoints(.all)
                    
                    // Estrai solo i punti validi
                    let keypoints = handLandmarks.values.filter { $0.confidence > 0.3 }.map { CGPoint(x: $0.location.x, y: $0.location.y) }
                    
                    // Passare i keypoints al modello CoreML
                    if keypoints.count > 0 {
                        handlePrediction(keypoints: keypoints)
                    }
                }
            } catch {
                print(error)
            }
        }
        
        public func exifOrientationFromDeviceOrientation() -> CGImagePropertyOrientation {
            let curDeviceOrientation = UIDevice.current.orientation
            let exifOrientation: CGImagePropertyOrientation
            
            switch curDeviceOrientation {
            case UIDeviceOrientation.portraitUpsideDown:
                exifOrientation = .left
            case UIDeviceOrientation.landscapeLeft:
                exifOrientation = .upMirrored
            case UIDeviceOrientation.landscapeRight:
                exifOrientation = .down
            case UIDeviceOrientation.portrait:
                exifOrientation = .up
            default:
                exifOrientation = .up
            }
            return exifOrientation
        }
        
        func setupAVCapture() {
            var deviceInput: AVCaptureDeviceInput!
            let videoDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back).devices.first
            do {
                deviceInput = try AVCaptureDeviceInput(device: videoDevice!)
            } catch {
                print("Errore nella creazione del dispositivo video: \(error)")
                return
            }
            
            session.beginConfiguration()
            session.sessionPreset = .vga640x480
            
            guard session.canAddInput(deviceInput) else {
                print("Impossibile aggiungere input video alla sessione")
                session.commitConfiguration()
                return
            }
            
            session.addInput(deviceInput)
            if session.canAddOutput(videoDataOutput) {
                session.addOutput(videoDataOutput)
                videoDataOutput.alwaysDiscardsLateVideoFrames = true
                videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
                videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
            } else {
                print("Impossibile aggiungere output video alla sessione")
                session.commitConfiguration()
                return
            }
            
            let captureConnection = videoDataOutput.connection(with: .video)
            captureConnection?.isEnabled = true
            
            session.commitConfiguration()
            previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
            rootLayer = previewView.layer
            previewLayer.frame = rootLayer.bounds
            rootLayer.addSublayer(previewLayer)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo
        
        guard let videoCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            return viewController
        }
        
        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return viewController
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            return viewController
        }
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(context.coordinator, queue: DispatchQueue(label: "videoQueue"))
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = viewController.view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        viewController.view.layer.addSublayer(previewLayer)
        
        captureSession.startRunning()
        
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.isShowingResult = showResult
    }
}


class CustomModelInput: MLFeatureProvider {
    var keypoints: [Double]
    
    // Definisci tutti i 42 attributi che il modello si aspetta
    var featureNames: Set<String> {
        return Set((0..<21).flatMap { ["x\($0)", "y\($0)"] })
    }
    
    init(keypoints: [Double]) {
        self.keypoints = keypoints
    }
    
    // Questo metodo restituisce il valore associato a ciascun nome di feature
    func featureValue(for featureName: String) -> MLFeatureValue? {
        // Ottieni l'indice dal nome dell'attributo (es. x0, y0, x1, y1, ...)
        let index = Int(String(featureName.dropFirst()))!
        
        if featureName.hasPrefix("x") {
            return MLFeatureValue(double: (Double)(keypoints[index * 2])) // Indice pari per X
        } else if featureName.hasPrefix("y") {
            return MLFeatureValue(double: (Double)(keypoints[index * 2 + 1])) // Indice dispari per Y
        } else {
            return nil
        }
    }
}
