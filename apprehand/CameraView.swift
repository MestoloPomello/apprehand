import SwiftUI
import AVFoundation
import CoreML
import Vision
import CoreImage
import Photos
import UIKit

struct CameraView: UIViewControllerRepresentable {
    
    @Binding var showResult: Bool
    
    class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        var isShowingResult: Bool = false
        var parent: CameraView
        var model: HandPoseClassifier?
        var request: VNCoreMLRequest?
        var foundLetters: [String: [Float]] = [:]
        private let handPoseClassifier = try? HandPoseClassifier()
        // int 0 = occorrenze
        // int 1 = max confidenza
        
        weak private var previewView: UIView!
        var bufferSize: CGSize = .zero
        var rootLayer: CALayer! = nil
        private let videoDataOutput = AVCaptureVideoDataOutput()
        private let session = AVCaptureSession()
        private var previewLayer: AVCaptureVideoPreviewLayer! = nil
        private let videoDataOutputQueue = DispatchQueue(
            label: "VideoDataOutput",
            qos: .userInitiated,
            attributes: [],
            autoreleaseFrequency: .workItem
        )
        
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
                print ("Errore nel caricamento del modello: \(error.localizedDescription)")
            }
        }

        func extractHandPose(from sampleBuffer: CMSampleBuffer, completion: @escaping ([CGPoint]?) -> Void) {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                completion(nil)
                return
            }

            let request = VNDetectHumanHandPoseRequest()
            request.maximumHandCount = 1

            let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try requestHandler.perform([request])
                    guard let results = request.results?.first else {
                        completion(nil)
                        return
                    }

                    // Ottieni i keypoints (ossia i punti della mano)
                    let keypoints = try results.recognizedPoints(.all)
                    
                    // Estrai i punti specifici ordinati come desiderato (wrist, thumbCMC, thumbMP, etc.)
                    let keypointNames: [VNHumanHandPoseObservation.JointName] = [
                        .wrist, .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
                        .indexMCP, .indexPIP, .indexDIP, .indexTip,
                        .middleMCP, .middlePIP, .middleDIP, .middleTip,
                        .ringMCP, .ringPIP, .ringDIP, .ringTip,
                        .littleMCP, .littlePIP, .littleDIP, .littleTip
                    ]
                    
                    var keypointPositions: [CGPoint] = []
                    for name in keypointNames {
                        if let point = keypoints[name], point.confidence > 0.5 {
                            keypointPositions.append(CGPoint(x: point.location.x, y: 1 - point.location.y)) // Normalizzato su 0-1
                        } else {
                            keypointPositions.append(.zero) // Placeholder per punti mancanti
                        }
                    }
                    
                    completion(keypointPositions)
                } catch {
                    completion(nil)
                }
            }
        }

        func createMLMultiArray(from keypoints: [CGPoint]) -> MLMultiArray? {
            guard keypoints.count == 21 else { return nil } // Assicurati che ci siano esattamente 21 punti

            // Crea un MLMultiArray con dimensioni [1, 3, 21]
            let shape: [NSNumber] = [1, 3, 21]
            guard let multiArray = try? MLMultiArray(shape: shape, dataType: .float32) else { return nil }

            // Inserisci i valori di x, y, e confidence (per ora confidence sarà impostato a 1.0 per ogni punto)
            for (index, point) in keypoints.enumerated() {
                multiArray[[0, 0, NSNumber(value: index)]] = NSNumber(value: Float(point.x))
                multiArray[[0, 1, NSNumber(value: index)]] = NSNumber(value: Float(point.y))
                multiArray[[0, 2, NSNumber(value: index)]] = 1.0 // Confidence a 1.0
            }

            return multiArray
        }

        func classifyHandPose(with multiArray: MLMultiArray) -> String? {
            do {
                let model = try HandPoseClassifier() // Inizializza il modello
                let output = try model.prediction(poses: multiArray) // Esegui la previsione
                return output.label // Restituisce la lettera prevista
            } catch {
                print("Errore nella classificazione: \(error)")
                return nil
            }
        }

        private func classifyHandPose(with multiArray: MLMultiArray) -> String? {
            guard let handPoseClassifier = handPoseClassifier else { return nil }

            do {
                // Effettua la predizione usando il modello con l'input MLMultiArray
                let output = try handPoseClassifier.prediction(poses: multiArray)

                // Restituisce l'etichetta con la previsione più probabile
                return output.label
            } catch {
                print("Errore durante la classificazione della posa della mano: \(error)")
                return nil
            }
        }
        
        // Funzione per l'inferenza diretta
        func classifyImage(buffer: CMSampleBuffer) {
            guard let model = self.model else { return }
            
            do {
                // Estrarre i punti dall'immagine
                extractHandPose(from: sampleBuffer) { keypoints in
                    guard let keypoints = keypoints, let mlArray = createMLMultiArray(from: keypoints) else {
                        recognizedLetter = "N/A"
                        return
                    }
                    
                    if let predictedLetter = classifyHandPose(with: mlArray) {
                        print("LETTERA PREDETTA:", predictedLetter)
                    }
                }

                // Esegue l'inferenza
                /*let prediction = try model.prediction(poses: multiArray)
                let letterValues = prediction.labelProbabilities
                print("letterValues", letterValues)
                
                
                //print("Label probabilities", prediction.labelProbabilities)
                if let (maxLetter, maxValue) = letterValues.max(by: { $0.value < $1.value }) {
                    print("La lettera con il valore massimo è: \(maxLetter) con valore \(maxValue)")
                } else {
                    print("Il dizionario è vuoto.")
                }*/
                
                // Recupera l'output
                /*if let predictedClass = prediction.featureValue(for: "classLabel")?.stringValue {
                 print("Predizione: \(predictedClass)")
                 // Gestisci la predizione
                 handlePrediction(prediction: predictedClass)
                 }*/
                
            } catch {
                print("Errore durante l'inferenza: \(error.localizedDescription)")
            }
        }
        
        func handlePrediction(prediction: String) {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .predictionDidUpdate, object: prediction)
            }
        }
        
        // Esegue l'inferenza ogni volta che viene catturato un frame
        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            // guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

            // Effettua la classificazione diretta
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
        
        previewLayer.connection?.videoOrientation = .portrait // = .pi / 2
        
        captureSession.startRunning()
        
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.isShowingResult = showResult
    }
    
}


extension UIImage {
    
    /// Crea un `UIImage` da un `CVPixelBuffer` usando `CIImage` e `CIContext`.
    convenience init?(fromPixelBuffer pixelBuffer: CVPixelBuffer) {
        // Crea un CIImage dal pixel buffer
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Crea un CIContext per rendere il CIImage
        let ciContext = CIContext(options: nil)
        
        // Ottiene le dimensioni del pixel buffer
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        // Crea un CGImage dal CIImage usando il contesto
        guard let cgImage = ciContext.createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: width, height: height)) else {
            print("Errore: impossibile creare un CGImage dal CIImage.")
            return nil
        }
        
        // Crea un'UIImage dal CGImage
        self.init(cgImage: cgImage)
    }
    
    /// Disegna i punti su una UIImage e restituisce la nuova immagine
    func drawPoints(points: [CGPoint], pointColor: UIColor = .red, pointSize: CGFloat = 5.0) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        
        // Disegna l'immagine di base
        self.draw(at: .zero)
        
        // Configura il contesto per disegnare i punti
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(pointColor.cgColor)
        
        // Disegna ogni punto
        for point in points {
            let rect = CGRect(x: point.x - pointSize / 2, y: point.y - pointSize / 2, width: pointSize, height: pointSize)
            print("rettangolo", rect)
            context?.fillEllipse(in: rect)
        }
        
        // Crea una nuova immagine dal contesto
        let imageWithPoints = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return imageWithPoints
    }
    
    func resize(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, self.scale)
        self.draw(in: CGRect(origin: .zero, size: size))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage
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
    }
    
    func mlMultiArray(scale preprocessScale:Double=255, rBias preprocessRBias:Double=0, gBias preprocessGBias:Double=0, bBias preprocessBBias:Double=0) -> MLMultiArray {
        let imagePixel = self.getPixelRgb(scale: preprocessScale, rBias: preprocessRBias, gBias: preprocessGBias, bBias: preprocessBBias)
        let size = self.size
        let imagePointer : UnsafePointer<Double> = UnsafePointer(imagePixel)
        let mlArray = try! MLMultiArray(shape: [3,  NSNumber(value: Float(size.width)), NSNumber(value: Float(size.height))], dataType: MLMultiArrayDataType.double)
        mlArray.dataPointer.initializeMemory(as: Double.self, from: imagePointer, count: imagePixel.count)
        return mlArray
    }
    
    func mlMultiArrayGrayScale(scale preprocessScale:Double=255,bias preprocessBias:Double=0) -> MLMultiArray {
        let imagePixel = self.getPixelGrayScale(scale: preprocessScale, bias: preprocessBias)
        let size = self.size
        let imagePointer : UnsafePointer<Double> = UnsafePointer(imagePixel)
        let mlArray = try! MLMultiArray(shape: [1,  NSNumber(value: Float(size.width)), NSNumber(value: Float(size.height))], dataType: MLMultiArrayDataType.double)
        mlArray.dataPointer.initializeMemory(as: Double.self, from: imagePointer, count: imagePixel.count)
        return mlArray
    }
    
    func getPixelRgb(scale preprocessScale:Double=255, rBias preprocessRBias:Double=0, gBias preprocessGBias:Double=0, bBias preprocessBBias:Double=0) -> [Double]
    {
        guard let cgImage = self.cgImage else {
            return []
        }
        let bytesPerRow = cgImage.bytesPerRow
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let pixelData = cgImage.dataProvider!.data! as Data
        
        var r_buf : [Double] = []
        var g_buf : [Double] = []
        var b_buf : [Double] = []
        
        for j in 0..<height {
            for i in 0..<width {
                let pixelInfo = bytesPerRow * j + i * bytesPerPixel
                let r = Double(pixelData[pixelInfo])
                let g = Double(pixelData[pixelInfo+1])
                let b = Double(pixelData[pixelInfo+2])
                r_buf.append(Double(r/preprocessScale)+preprocessRBias)
                g_buf.append(Double(g/preprocessScale)+preprocessGBias)
                b_buf.append(Double(b/preprocessScale)+preprocessBBias)
            }
        }
        return ((b_buf + g_buf) + r_buf)
    }
    
    func getPixelGrayScale(scale preprocessScale:Double=255, bias preprocessBias:Double=0) -> [Double]
    {
        guard let cgImage = self.cgImage else {
            return []
        }
        let bytesPerRow = cgImage.bytesPerRow
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 2
        let pixelData = cgImage.dataProvider!.data! as Data
        
        var buf : [Double] = []
        
        for j in 0..<height {
            for i in 0..<width {
                let pixelInfo = bytesPerRow * j + i * bytesPerPixel
                let v = Double(pixelData[pixelInfo])
                buf.append(Double(v/preprocessScale)+preprocessBias)
            }
        }
        return buf
    }
}
