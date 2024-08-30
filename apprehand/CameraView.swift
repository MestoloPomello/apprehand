import SwiftUI
import AVFoundation
import CoreML
import Vision

// CameraView per gestire la cattura video
struct CameraView: UIViewControllerRepresentable {
    class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        var parent: CameraView
        var model: VNCoreMLModel
        var request: VNCoreMLRequest
        
        init(parent: CameraView) {
        //override init() {
            self.parent = parent
            
            // Carica il modello CoreML
            guard let model = try? VNCoreMLModel(for: ASL_Classifier(configuration: MLModelConfiguration()).model) else {
                fatalError("Unable to load model")
            }
            self.model = model
            self.request = VNCoreMLRequest(model: model) { _, _ in }
            
            super.init()
            
            // Crea una richiesta VNCoreMLRequest usando il modello
            self.request = VNCoreMLRequest(model: model) { [weak self] request, error in
                self?.handleRequest(request: request, error: error)
            }
            self.request.imageCropAndScaleOption = .scaleFill
        }
        
        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            do {
                try handler.perform([self.request])
            } catch {
                print("Failed to perform request: \(error)")
            }
        }
        
        func handleRequest(request: VNRequest, error: Error?) {
            guard let results = request.results as? [VNClassificationObservation], let bestResult = results.first else { return }
            DispatchQueue.main.async {
                self.parent.handlePrediction(prediction: bestResult.identifier)
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
        
        guard let videoCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
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
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    func handlePrediction(prediction: String) {
        NotificationCenter.default.post(name: .predictionDidUpdate, object: prediction)
    }
}

