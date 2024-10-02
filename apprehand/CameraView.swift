import SwiftUI
import AVFoundation
import CoreML
import Vision
import CoreImage
import Photos
import UIKit

// CameraView per gestire la cattura video
struct CameraView: UIViewControllerRepresentable {

    @Binding var showResult: Bool

    class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        var isShowingResult: Bool = false
        var parent: CameraView
        var model: HandPoseClassifier?
        var request: VNCoreMLRequest?
        var foundLetters: [String: [Float]] = [:]
        // int 0 = occorrenze
        // int 1 = max confidenza

        weak private var previewView: UIView!
        var bufferSize: CGSize = .zero
        var rootLayer: CALayer! = nil
        private let videoDataOutput = AVCaptureVideoDataOutput()
        private let session = AVCaptureSession()
        private var previewLayer: AVCaptureVideoPreviewLayer! = nil
        private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)

        init(parent: CameraView) {
            self.parent = parent
            self.foundLetters = [:]
            
            super.init()
            
            self.loadModel()
        }

        func loadModel() {
            do {
                self.model = try HandPoseClassifier(configuration: MLModelConfiguration())
            } catch {
                print("Errore nel caricamento del modello: \(error.localizedDescription)")
            }
        }

        // Funzione per l'inferenza diretta con il modello
        func classifyImage(buffer: CMSampleBuffer) {
            guard let model = self.model,
                  let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) else { return }

            // Configurazione di un VNDetectHumanHandPoseRequest per riconoscere la posa della mano
            let request = VNDetectHumanHandPoseRequest()
            request.maximumHandCount = 1

            // Calcolo dell'orientamento corretto usando il metodo `cgOrientationFromDevicePosition`
            let orientation = cgOrientationFromDevicePosition()

            // Configurazione del VNImageRequestHandler con orientamento corretto
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])

            do {
                // Esegui la richiesta di rilevamento della posa
                try handler.perform([request])

                // Se otteniamo una posa, estraiamo i keypoints
                if let result = request.results?.first as? VNHumanHandPoseObservation,
                   let keypointsMultiArray = extractKeypoints(from: result) {

                    // Usa il modello CoreML per fare la previsione
                    if let predictionLabel = classifyHandPose(with: keypointsMultiArray) {
                        handlePrediction(prediction: predictionLabel)
                    }
                }
            } catch {
                print("Errore durante l'analisi del frame: \(error.localizedDescription)")
            }
        }
        
        private func cgOrientationFromDevicePosition() -> CGImagePropertyOrientation {
            let devicePosition = UIDevice.current.orientation
            switch devicePosition {
            case .portrait:
                return .right // L'immagine è ruotata di 90° in senso antiorario
            case .landscapeLeft:
                return .down // Rotata di 180°
            case .landscapeRight:
                return .up // Orientamento corretto
            case .portraitUpsideDown:
                return .left // Rotata di 270°
            default:
                return .right // Default: ruotata di 90°
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

        // Gestione della predizione e invio di notifiche
        func handlePrediction(prediction: String) {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .predictionDidUpdate, object: prediction)
            }
        }

        // Esegue l'inferenza ogni volta che viene catturato un frame
        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard let _ = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            classifyImage(buffer: sampleBuffer)
        }

        public func exifOrientationFromDeviceOrientation() -> CGImagePropertyOrientation {
            let curDeviceOrientation = UIDevice.current.orientation
            let exifOrientation: CGImagePropertyOrientation
            
            switch curDeviceOrientation {
            case UIDeviceOrientation.portraitUpsideDown:  // Device oriented vertically, home button on the top
                exifOrientation = .left
            case UIDeviceOrientation.landscapeLeft:       // Device oriented horizontally, home button on the right
                exifOrientation = .upMirrored
            case UIDeviceOrientation.landscapeRight:      // Device oriented horizontally, home button on the left
                exifOrientation = .down
            case UIDeviceOrientation.portrait:            // Device oriented vertically, home button on the bottom
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
                print("Could not create video device input: \(error)")
                return
            }
            
            session.beginConfiguration()
            session.sessionPreset = .vga640x480
            
            guard session.canAddInput(deviceInput) else {
                print("Could not add video device input to the session")
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
                print("Could not add video data output to the session")
                session.commitConfiguration()
                return
            }
            
            let captureConnection = videoDataOutput.connection(with: .video)
            captureConnection?.isEnabled = true
            
            do {
                try videoDevice!.lockForConfiguration()
                let dimensions = CMVideoFormatDescriptionGetDimensions((videoDevice?.activeFormat.formatDescription)!)
                bufferSize.width = CGFloat(dimensions.width)
                bufferSize.height = CGFloat(dimensions.height)
                videoDevice!.unlockForConfiguration()
            } catch {
                print(error)
            }
            
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
        
        previewLayer.connection?.videoOrientation = .portrait
        
        captureSession.startRunning()
        
        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.isShowingResult = showResult
    }
}
