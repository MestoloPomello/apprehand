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
            //upModelAndRequest()
        }
        
        func loadModel() {
            do {
                self.model = try HandPoseClassifier(configuration: MLModelConfiguration())
            } catch {
                print ("Errore nel caricamento del modello: \(error.localizedDescription)")
            }
        }
        
        // Funzione per l'inferenza diretta
        func classifyImage(buffer: CMSampleBuffer) {
            guard let model = self.model else { return }
            
            do {
                // Converte l'immagine in CVPixelBuffer
                /*guard let pixelBuffer = image.toCVPixelBuffer() else {
                 print("Errore nella conversione dell'immagine in CVPixelBuffer")
                 return
                 }*/
                
                //guard let multiArray = image.toMLMultiArray(size: CGSize(width: 21, height: 3)) else {
                
                //saveImageFromBuffer(buffer)
                
                guard let multiArray: MLMultiArray = extractKeypointsForHandPoseClassifier(from: buffer) else
                {
                    print("Errore nell'estrazione dei punti")
                    return
                }
                
                //let multiArray = image.mlMultiArray()
                
                // Crea un input per il modello
                /*let input = try HandPoseClassifierInput(poses: [
                 "image" : MLFeatureValue(pixelBuffer: pixelBuffer)
                 ])*/
                
                // Esegue l'inferenza
                let prediction = try model.prediction(poses: multiArray)
                let letterValues = prediction.labelProbabilities
                print("letterValues", letterValues)
                
                
                //print("Label probabilities", prediction.labelProbabilities)
                if let (maxLetter, maxValue) = letterValues.max(by: { $0.value < $1.value }) {
                    print("La lettera con il valore massimo è: \(maxLetter) con valore \(maxValue)")
                } else {
                    print("Il dizionario è vuoto.")
                }
                
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
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            
            // Converte il pixelBuffer in UIImage per la classificazione
            //let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            //let uiImage = UIImage(ciImage: ciImage)
            
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
        
        previewLayer.connection?.videoOrientation = .portrait // = .pi / 2
        
        captureSession.startRunning()
        
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.isShowingResult = showResult
    }
    
}

func rotateCVPixelBufferUsingCG(_ pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
    let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        var rotatedPixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            nil,
            height,  // Altezza e larghezza invertite
            width,
            CVPixelBufferGetPixelFormatType(pixelBuffer),
            nil,
            &rotatedPixelBuffer
        )

        guard status == kCVReturnSuccess, let outputBuffer = rotatedPixelBuffer else {
            print("Errore nella creazione del buffer ruotato.")
            return nil
        }

        // Lock base addresses
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        CVPixelBufferLockBaseAddress(outputBuffer, .readOnly)

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer),
              let outputBaseAddress = CVPixelBufferGetBaseAddress(outputBuffer) else {
            print("Errore nell'accesso all'indirizzo base del buffer.")
            return nil
        }

        // Calculate bytes per row correctly
        let bytesPerRowInput = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let bytesPerRowOutput = height * 4 // 4 bytes per pixel (RGBA)

        // Create input and output context
        let inputContext = CGContext(data: baseAddress,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRowInput,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)

        let outputContext = CGContext(data: outputBaseAddress,
                                       width: height,
                                       height: width,
                                       bitsPerComponent: 8,
                                       bytesPerRow: bytesPerRowOutput,
                                       space: CGColorSpaceCreateDeviceRGB(),
                                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)

        // Rotate context
        outputContext?.translateBy(x: CGFloat(height), y: 0)
        outputContext?.rotate(by: .pi / 2)

        // Draw the input context in the output context
        if let cgImage = inputContext?.makeImage() {
            outputContext?.draw(cgImage, in: CGRect(x: 0, y: 0, width: height, height: width))
        } else {
            print("Errore nella creazione dell'immagine dal contesto di input.")
        }

        // Unlock base addresses
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        CVPixelBufferUnlockBaseAddress(outputBuffer, .readOnly)

        return outputBuffer}

/// Funzione che prende un `CVPixelBuffer` come input e restituisce un `MLMultiArray` con i keypoints estratti.
func extractKeypointsForHandPoseClassifier(from pixelBuffer: CVPixelBuffer) -> MLMultiArray? {
    // Step 1: Creare una richiesta per rilevare la posa della mano usando Vision
    
    //let rotatedPixelBuffer = rotateCVPixelBufferUsingCG(pixelBuffer)
    let rotatedPixelBuffer = pixelBuffer
    
    let handPoseRequest = VNDetectHumanHandPoseRequest()
    handPoseRequest.maximumHandCount = 1
    
    // Step 2: Creare un gestore di richieste Vision usando il pixel buffer
    let requestHandler = VNImageRequestHandler(cvPixelBuffer: rotatedPixelBuffer, options: [:])
    
    do {
        // Eseguire la richiesta su CVPixelBuffer
        try requestHandler.perform([handPoseRequest])
        
        // Ottenere la prima mano rilevata
        guard let observation = handPoseRequest.results?.first else {
            print("Nessuna mano rilevata nel buffer.")
            return nil
        }
        
        // Step 3: Estrarre i punti chiave della mano
        let handLandmarks = try observation.recognizedPoints(.all)
        
        // Step 4: Creare un array per memorizzare i punti chiave con (x, y, confidence)
        var keypointsArray: [Float] = Array(repeating: 0.0, count: 63)  // 3 valori per 21 punti chiave
        
        // Converti l'MLMultiArray in un array di `CGPoint`
        var keypoints: [CGPoint] = []
        for i in 0..<21 {
            let x = keypointsArray[i * 3]//.floatValue
            let y = keypointsArray[i * 3 + 1]//.floatValue
            keypoints.append(CGPoint(x: CGFloat(x), y: CGFloat(y)))
        }
        
        let jointNames: [VNHumanHandPoseObservation.JointName] = [
            .wrist, .thumbCMC, .thumbMP, .thumbIP, .thumbTip, .indexMCP, .indexPIP, .indexDIP, .indexTip,
            .middleMCP, .middlePIP, .middleDIP, .middleTip, .ringMCP, .ringPIP, .ringDIP, .ringTip,
            .littleMCP, .littlePIP, .littleDIP, .littleTip
        ]
        
        // Iterare attraverso i nomi dei punti giuntura per ottenere le coordinate x, y e confidence
        for (index, jointName) in jointNames.enumerated() {
            if let point = handLandmarks[jointName], point.confidence > 0.3 {
                // Se la confidenza è maggiore di 0.3, aggiungi le coordinate (x, y) e la confidenza
                keypointsArray[index * 3] = Float(point.location.x)
                keypointsArray[index * 3 + 1] = Float(point.location.y)
                keypointsArray[index * 3 + 2] = Float(point.confidence)
            } else {
                // Se non c'è confidenza sufficiente, lascia i valori a zero
                keypointsArray[index * 3] = 0.0
                keypointsArray[index * 3 + 1] = 0.0
                keypointsArray[index * 3 + 2] = 0.0
            }
        }
        
        // Step 5: Creare il MLMultiArray con forma [1, 3, 21] e inserire i dati estratti
        guard let multiArray = try? MLMultiArray(shape: [1, 3, 21], dataType: .float32) else {
            print("Errore nella creazione di MLMultiArray.")
            return nil
        }
        
        // Inserire i dati nell'MLMultiArray
        for i in 0..<keypointsArray.count {
            multiArray[i] = NSNumber(value: keypointsArray[i])
        }
        
        return multiArray
        
    } catch {
        print("Errore nell'estrazione dei punti chiave: \(error.localizedDescription)")
        return nil
    }
}

/// Funzione per convertire `CMSampleBuffer` in `MLMultiArray` per il classificatore di pose
func extractKeypointsForHandPoseClassifier(from sampleBuffer: CMSampleBuffer) -> MLMultiArray? {
    // Step 1: Ottenere il `CVPixelBuffer` dal `CMSampleBuffer`
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
        print("Errore nel recupero del CVPixelBuffer dal CMSampleBuffer.")
        return nil
    }
    
    // Step 2: Chiamare la funzione che estrae i punti chiave dal `CVPixelBuffer`
    return extractKeypointsForHandPoseClassifier(from: pixelBuffer)
}


// Funzione per ruotare l'immagine di 90 gradi in senso orario
func rotateUIImage(image: UIImage, clockwise: Bool = true) -> UIImage? {
    let radians = clockwise ? CGFloat.pi / 2 : -CGFloat.pi / 2
    var newSize = CGSize(width: image.size.height, height: image.size.width)
    
    UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
    guard let context = UIGraphicsGetCurrentContext() else { return nil }
    
    // Sposta il contesto al centro
    context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
    // Ruota il contesto
    context.rotate(by: radians)
    // Disegna l'immagine nel contesto, invertendo la scala (per mantenere l'orientamento)
    context.scaleBy(x: 1.0, y: -1.0)
    context.draw(image.cgImage!, in: CGRect(x: -image.size.width / 2, y: -image.size.height / 2, width: image.size.width, height: image.size.height))
    
    // Crea una nuova immagine dal contesto
    let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    
    return rotatedImage
}

/// Funzione per disegnare i keypoints su una `UIImage` e salvare il risultato.
func saveImageWithKeypoints(from pixelBuffer: CVPixelBuffer, keypoints: [CGPoint], outputFileName: String = "keypointsImage") {
    // Convertire il CVPixelBuffer in UIImage
    guard let image = UIImage(fromPixelBuffer: pixelBuffer) else {
        print("Errore nella conversione da CVPixelBuffer a UIImage.")
        return
    }
    
    // Creare un contesto grafico per disegnare sull'immagine
    UIGraphicsBeginImageContext(image.size)
    let context = UIGraphicsGetCurrentContext()
    image.draw(at: CGPoint.zero)
    
    // Impostare i parametri di disegno
    context?.setStrokeColor(UIColor.red.cgColor)
    context?.setLineWidth(5.0)
    
    // Disegnare i keypoints come cerchi sull'immagine
    for point in keypoints {
        // Calcolare le coordinate in base alla dimensione dell'immagine
        let scaledPoint = CGPoint(x: point.x * image.size.width, y: (1 - point.y) * image.size.height)
        context?.addArc(center: scaledPoint, radius: 5.0, startAngle: 0.0, endAngle: .pi * 2, clockwise: true)
        context?.fillPath()
    }
    
    // Recuperare l'immagine risultante
    let imageWithKeypoints = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    
    // Verificare che l'immagine con i keypoints sia stata creata
    guard let finalImage = imageWithKeypoints else {
        print("Errore nella creazione dell'immagine finale con i keypoints.")
        return
    }
    
    // Richiedere l'autorizzazione per salvare nella libreria delle foto
    PHPhotoLibrary.requestAuthorization { status in
        switch status {
        case .authorized:
            // Salva l'immagine nella libreria delle foto
            UIImageWriteToSavedPhotosAlbum(finalImage, nil, nil, nil)
            print("Immagine con keypoints salvata nella galleria delle foto.")
        case .denied, .restricted:
            print("Accesso alla libreria delle foto negato o limitato.")
        case .notDetermined:
            print("Permesso di accesso alla libreria non determinato.")
        @unknown default:
            print("Stato di accesso sconosciuto.")
        }
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
