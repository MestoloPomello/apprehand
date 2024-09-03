import SwiftUI
import AVFoundation
import CoreML
import Vision
import CoreImage

// CameraView per gestire la cattura video
struct CameraView: UIViewControllerRepresentable {
    class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        var parent: CameraView
        var model: VNCoreMLModel
        var request: VNCoreMLRequest
        
        init(parent: CameraView) {
            self.parent = parent
            
            // Caricamento del modello CoreML
            guard let model = try? VNCoreMLModel(for: ASL_Classifier(configuration: MLModelConfiguration()).model) else {
                fatalError("Failed to load model")
            }
            self.model = model
            let request = VNCoreMLRequest(model: model, completionHandler: { (request, error) in
                if let error = error {
                    print("Error during the request: \(error.localizedDescription)")
                    return
                }
                
                guard let results = request.results as? [VNClassificationObservation] else {
                    print("No results found, or results are not of expected type.")
                    return
                }
                
                if results.isEmpty {
                    print("No classification results were returned.")
                } else {
                    for result in results {
                        print("Result: \(result.identifier) with confidence: \(result.confidence)")
                    }
                }
                
                /*if let bestResult = results.first {
                    let predictedClass = bestResult.identifier
                    let confidence = bestResult.confidence
                    print("Predicted class: \(predictedClass) with confidence: \(confidence)")
                    
                    DispatchQueue.main.async {
                        //self.parent.handlePrediction(prediction: predictedClass)
                    }
                } else {
                    print("No classification results were returned.")
                }*/
            })
            self.request = request
            self.request.imageCropAndScaleOption = .centerCrop
        }
        
        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer) // Conversione a CIImage
            
            let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
            do {
                try handler.perform([self.request])
            } catch {
                print("Error performing request: \(error)")
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
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    func handlePrediction(prediction: String) {
        NotificationCenter.default.post(name: .predictionDidUpdate, object: prediction)
    }
}

