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
        
        weak private var previewView: UIView!
        var bufferSize: CGSize = .zero
        var rootLayer: CALayer! = nil
        private let videoDataOutput = AVCaptureVideoDataOutput()
        private let session = AVCaptureSession()
        private var previewLayer: AVCaptureVideoPreviewLayer! = nil
        private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
        
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
                
                print("request.results", request.results)
                
                guard let results = request.results as? [VNRecognizedObjectObservation], let bestResult = results.first else { return }
                
                print("Miglior risultato", bestResult.labels)
                
                /*guard let results = request.results as? [VNClassificationObservation] else {
                 print("No results found, or results are not of expected type.")
                 return
                 }*/
                
                /*if results.isEmpty {
                 print("No classification results were returned.")
                 } else {
                 for result in results {
                 print("Result: \(result.identifier) with confidence: \(result.confidence)")
                 }
                 }
                 
                 if let bestResult = results.first {
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
        
        // override func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        //     guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        //     let ciImage = CIImage(cvPixelBuffer: pixelBuffer) // Conversione a CIImage
        
        //     let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        //     do {
        //         try handler.perform([self.request])
        //     } catch {
        //         print("Error performing request: \(error)")
        //     }
        // }
        
        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            
            let exifOrientation = exifOrientationFromDeviceOrientation()
            
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: [:])
            do {
                try imageRequestHandler.perform([self.request])
            } catch {
                print(error)
            }
        }
        
        func handleRequest(request: VNRequest, error: Error?) {
            guard let results = request.results as? [VNClassificationObservation], let bestResult = results.first else { return }
            DispatchQueue.main.async {
                self.parent.handlePrediction(prediction: bestResult.identifier)
            }
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
            
            // Select a video device, make an input. We want to use the camera facing the world, not the user.
            let videoDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back).devices.first
            do {
                deviceInput = try AVCaptureDeviceInput(device: videoDevice!)
            } catch {
                print("Could not create video device input: \(error)")
                return
            }
            
            session.beginConfiguration()
            session.sessionPreset = .vga640x480 // Model image size is smaller.
            
            // Add a video input
            guard session.canAddInput(deviceInput) else {
                print("Could not add video device input to the session")
                session.commitConfiguration()
                return
            }
            
            session.addInput(deviceInput)
            if session.canAddOutput(videoDataOutput) {
                session.addOutput(videoDataOutput)
                // Add a video data output
                videoDataOutput.alwaysDiscardsLateVideoFrames = true
                videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
                videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
            } else {
                print("Could not add video data output to the session")
                session.commitConfiguration()
                return
            }
            
            let captureConnection = videoDataOutput.connection(with: .video)
            // Always process the frames
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
        
        captureSession.startRunning()
        
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    func handlePrediction(prediction: String) {
        NotificationCenter.default.post(name: .predictionDidUpdate, object: prediction)
    }
}

