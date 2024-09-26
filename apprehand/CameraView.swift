import SwiftUI
import AVFoundation
import CoreML
import Vision
import CoreImage
import Photos

// CameraView per gestire la cattura video
struct CameraView: UIViewControllerRepresentable {
    
    @Binding var showResult: Bool
    
    class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        var isShowingResult: Bool = false
        var parent: CameraView
        var model: VNCoreMLModel?
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
            
            setupModelAndRequest()
        }
        
        func setupModelAndRequest() {
            // Caricamento del modello CoreML
            guard let model = try? VNCoreMLModel(for: apprehand_Image_2409(configuration: MLModelConfiguration()).model) else {
                fatalError("Failed to load model")
            }
            self.model = model
            lazy var request = VNCoreMLRequest(model: model, completionHandler: { (request, error) in
                if let error = error {
                    print("Error during the request: \(error.localizedDescription)")
                    return
                }
                
                if self.isShowingResult {
                    return
                }
                
                guard let results = request.results as? [VNClassificationObservation], let bestResult = results.first else { return }
                
                //print("Risultati", results)
                print("Miglior risultato", bestResult.identifier)
                
                var isCalculating = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    isCalculating = false
                }
                
                while isCalculating {
                    let foundLetter = bestResult.identifier
                    let confidence = bestResult.confidence
                    
                    if self.foundLetters[foundLetter] == nil {
                        self.foundLetters[foundLetter] = [-1, -1]
                    } else {
                        self.foundLetters[foundLetter]?[0] += 1
                    }
                    
                    if confidence > (self.foundLetters[foundLetter]?[1])! {
                        self.foundLetters[foundLetter]?[1] = confidence
                    }
                }
                
                var maxOccurrences: Float = -1
                var maxLetter: String = ""
                var maxConfidence: Float = -1
                
                // {}[]
                
                for lettera in self.foundLetters {
                    if (
                        (lettera.value[0] == maxOccurrences && lettera.value[1] > maxConfidence) ||
                        (lettera.value[0] > maxOccurrences)
                    ) {
                        maxLetter = lettera.key
                        maxConfidence = lettera.value[1]
                        maxOccurrences = lettera.value[0]
                    }
                }
                
                self.foundLetters = [:]
                
                print("Lettera rilevata", maxLetter)
                self.handlePrediction(prediction: maxLetter)
            })
            self.request = request
            self.request?.imageCropAndScaleOption = .centerCrop
        }
        
        func handlePrediction(prediction: String) {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .predictionDidUpdate, object: prediction)
            }
        }
        
        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            
            if isShowingResult {
                return
            }
            
            guard let resizedImage = preprocessImage(sampleBuffer) else { return }
            
            //guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            guard let pixelBuffer = resizedImage.toCVPixelBuffer() else { return }
            let exifOrientation = exifOrientationFromDeviceOrientation()
            
            saveImageFromBuffer(sampleBuffer)
            
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: [:])
            do {
                try imageRequestHandler.perform([self.request!])
            } catch {
                print(error)
            }
        }
        
        /*func handleRequest(request: VNRequest, error: Error?) {
         guard let results = request.results as? [VNClassificationObservation], let bestResult = results.first else { return }
         DispatchQueue.main.async {
         self.parent.handlePrediction(prediction: bestResult.identifier)
         }
         }*/
        
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
        
        func saveImageFromBuffer(_ buffer: CMSampleBuffer) {
            /*guard let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) else { return }
             
             // Crea un CIImage dal pixel buffer
             let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
             
             // Crea un contesto per convertire CIImage in UIImage
             let context = CIContext()
             guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
             
             // Converti CGImage in UIImage
             let uiImage = UIImage(cgImage: cgImage)*/
            
            guard let uiImage = preprocessImage(buffer) else { return }
            
            PHPhotoLibrary.requestAuthorization { status in
                if status == .authorized {
                    // Salva l'immagine nella libreria delle foto
                    UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
                    print("Immagine salvata nelle foto.")
                } else {
                    print("Permesso per accedere alla libreria delle foto non concesso.")
                }
            }
            /*let activityViewController = UIActivityViewController(activityItems: [uiImage], applicationActivities: nil)
             if let viewController = UIApplication.shared.windows.first?.rootViewController {
             viewController.present(activityViewController, animated: true, completion: nil)
             }*/
            
            // Converti UIImage in dati PNG o JPEG
            /*guard let imageData = uiImage.jpegData(compressionQuality: 1.0) else { return } // Puoi anche usare uiImage.pngData()
             
             // Definisci il percorso per salvare l'immagine
             let fileManager = FileManager.default
             let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
             let fileURL = documentsURL.appendingPathComponent("captured_frame.jpg")
             
             do {
             // Scrivi i dati dell'immagine nel file
             try imageData.write(to: fileURL)
             print("Immagine salvata con successo in: \(fileURL)")
             } catch {
             print("Errore nel salvataggio dell'immagine: \(error)")
             }*/
        }
        
        func preprocessImage(_ sampleBuffer: CMSampleBuffer) -> UIImage? {
            // Estrai l'immagine dal buffer
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
            
            // Converti l'immagine in CIImage
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            
            // Calcola il rettangolo per ritagliare l'immagine al centro in formato quadrato
            let imageSize = ciImage.extent.size
            let minSide = min(imageSize.width, imageSize.height)
            let cropRect = CGRect(x: (imageSize.width - minSide) / 2,
                                  y: (imageSize.height - minSide) / 2,
                                  width: minSide,
                                  height: minSide)
            
            // Crea una nuova CIImage ritagliata
            let croppedCIImage = ciImage.cropped(to: cropRect)
            
            // Converti l'immagine ritagliata in UIImage per facilitare la rotazione
            let context = CIContext()
            guard let cgImage = context.createCGImage(croppedCIImage, from: croppedCIImage.extent) else { return nil }
            let croppedUIImage = UIImage(cgImage: cgImage)
            
            // Ruota l'immagine a destra di 90 gradi
            let rotatedUIImage = croppedUIImage.rotate(radians: .pi / 2)
            
            // Ridimensiona l'immagine ruotata a 200x200 pixel
            let resizedImage = rotatedUIImage.resize(to: CGSize(width: 200, height: 200))
            
            return resizedImage
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

extension UIImage {
    // Estensione per ridimensionare un'immagine a una nuova dimensione
    func resize(to size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        draw(in: CGRect(origin: .zero, size: size))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage ?? self
    }
    
    // Estensione per ruotare un'immagine di un angolo specifico in radianti
    func rotate(radians: CGFloat) -> UIImage {
        var newSize = CGRect(origin: .zero, size: size)
            .applying(CGAffineTransform(rotationAngle: radians))
            .integral.size
        // Correggi la dimensione
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, scale)
        let context = UIGraphicsGetCurrentContext()!
        
        // Sposta il contesto al centro della nuova dimensione
        context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
        // Ruota il contesto
        context.rotate(by: radians)
        // Disegna l'immagine nel contesto, tenendo conto della rotazione e traslazione
        draw(in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
        
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return rotatedImage ?? self
    }
    
    func toCVPixelBuffer() -> CVPixelBuffer? {
        let width = Int(self.size.width)
        let height = Int(self.size.height)
        var pixelBuffer: CVPixelBuffer?
        
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary
        
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: pixelData, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                      space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else {
            return nil
        }
        
        guard let cgImage = self.cgImage else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        CVPixelBufferUnlockBaseAddress(buffer, [])
        
        return buffer
    }}
