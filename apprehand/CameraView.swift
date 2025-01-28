import SwiftUI
import AVFoundation
import CoreML
import Vision
import CoreImage
import Photos
import UIKit

struct CameraView: UIViewControllerRepresentable {
    
    @Binding var showResult: Bool
    var lvNumber: Int
    @Binding var letter: String
    
    class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        var parent: CameraView
        var model: HandPoseClassifier?
        var request: VNCoreMLRequest?
        
        var predictions: [String] = []
        var isCalculating: Bool = false
        
        weak private var previewView: UIView!
        var bufferSize: CGSize = .zero
        var rootLayer: CALayer! = nil
        private let videoDataOutput = AVCaptureVideoDataOutput()
        private let session = AVCaptureSession()
        private var previewLayer: AVCaptureVideoPreviewLayer! = nil
        private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
        
        init(parent: CameraView) {
            self.parent = parent
            super.init()
            self.loadModel()
        }
        
        func buildTimer() {
            if !self.parent.showResult {
                isCalculating = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    self.isCalculating = false
                    self.finalizePredictions()
                }
            }
        }
        
        func loadModel() {
            do {
                self.model = try HandPoseClassifier(configuration: MLModelConfiguration())
            } catch {
                print("Errore nel caricamento del modello: \(error.localizedDescription)")
            }
        }
        
        // Funzione per l'inferenza diretta con il modello
        func classifyImage(buffer: CMSampleBuffer) -> String {
            guard let model = self.model,
                  let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) else { return "" }
            
            let request = VNDetectHumanHandPoseRequest()
            request.maximumHandCount = 1
            
            let orientation = cgOrientationFromDevicePosition()
            
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
            
            do {
                try handler.perform([request])
                
                if let result = request.results?.first as? VNHumanHandPoseObservation,
                   let keypointsMultiArray = extractKeypoints(from: result) {
                    
                    if let predictionLabel = classifyHandPose(with: keypointsMultiArray) {
                        return predictionLabel
                    }
                }
            } catch {
                print("Errore durante l'analisi del frame: \(error.localizedDescription)")
                return ""
            }
            return ""
        }
        
        // Classificazione della posa della mano usando il modello CoreML
        private func classifyHandPose(with multiArray: MLMultiArray) -> String? {
            guard let handPoseClassifier = model else { return nil }
            
            do {
                let output = try handPoseClassifier.prediction(poses: multiArray)
                return output.label
            } catch {
                print("Errore durante la classificazione della posa della mano: \(error.localizedDescription)")
                return nil
            }
        }
        
        func handlePrediction(prediction: String) {
            predictions.append(prediction)
        }
        
        // Funzione per elaborare le previsioni e trovare quella più frequente
        func finalizePredictions() {
            guard !predictions.isEmpty else { return }
            
            var groupPredictions: [String] = []
            predictions.forEach { prediction in
                let isContains = lettersLevels[self.parent.lvNumber]?.contains(prediction.lowercased()) ?? false
                
                if isContains {
                    groupPredictions.append(prediction)
                }
            }
            
            print("GroupPrediction", groupPredictions)
            
            var finalPrediction: String = ""
            
            if groupPredictions.isEmpty && !predictions.isEmpty {
                finalPrediction = predictions[0]
            } else if !groupPredictions.isEmpty {
                /*finalPrediction = groupPredictions
                    .reduce(into: [:]) { counts, prediction in counts[prediction, default: 0] += 1 }
                    .max { $0.1 < $1.1 }?.0 ?? ""*/
                let isContains = groupPredictions.contains(self.parent.letter.uppercased())
                if isContains {
                    finalPrediction = self.parent.letter.uppercased()
                } else {
                    finalPrediction = groupPredictions[0]
                }
            }
            
            // Invia la previsione finale tramite una notifica o un callback
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .predictionDidUpdate, object: finalPrediction)
            }
            
            predictions = []
        }
        
        // Esegue l'inferenza ogni volta che viene catturato un frame
        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            
            if self.parent.showResult == true { return }
            if isCalculating == false {
                buildTimer()
            }
                        
            guard let _ = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                return
            }
            
            let prediction = classifyImage(buffer: sampleBuffer)
            if !prediction.isEmpty {
                handlePrediction(prediction: prediction)
            }
        }
        
        private func cgOrientationFromDevicePosition() -> CGImagePropertyOrientation {
            let devicePosition = UIDevice.current.orientation
            switch devicePosition {
            case .portrait:
                return .right
            case .landscapeLeft:
                return .down
            case .landscapeRight:
                return .up
            case .portraitUpsideDown:
                return .left
            default:
                return .right
            }
        }
        
        // Estrazione dei keypoints dalla mano
        private func extractKeypoints(from handPose: VNHumanHandPoseObservation) -> MLMultiArray? {
            do {
                let keypointsMultiArray = try handPose.keypointsMultiArray()
                return keypointsMultiArray
            } catch {
                print("Errore durante l'estrazione dei keypoints: \(error.localizedDescription)")
                return nil
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
        
        previewLayer.connection?.videoOrientation = .portrait
        
        captureSession.startRunning()
        
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        //context.coordinator.isShowingResult = showResult
        //context.coordinator.buildTimer()
    }
}
