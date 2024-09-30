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
            //setupModelAndRequest()
        }
        
        func loadModel() {
            do {
                self.model = try HandPoseClassifier(configuration: MLModelConfiguration())
            } catch {
                print ("Errore nel caricamento del modello: \(error.localizedDescription)")
            }
        }
        
        // Funzione per l'inferenza diretta
                func classifyImage(image: UIImage) {
                    guard let model = self.model else { return }

                    do {
                        // Converte l'immagine in CVPixelBuffer
                        /*guard let pixelBuffer = image.toCVPixelBuffer() else {
                            print("Errore nella conversione dell'immagine in CVPixelBuffer")
                            return
                        }*/
                        
                        //guard let multiArray = image.toMLMultiArray(size: CGSize(width: 21, height: 3)) else {
                        let multiArray = image.mlMultiArray()
                        
                        // Crea un input per il modello
                        /*let input = try HandPoseClassifierInput(poses: [
                            "image" : MLFeatureValue(pixelBuffer: pixelBuffer)
                        ])*/

                        // Esegue l'inferenza
                        let prediction = try model.prediction(poses: multiArray)
                        let letterValues = prediction.labelProbabilities
                        
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



        /*func setupModelAndRequest() {
            // Caricamento del modello CoreML
            do {
                let model = try HandPoseClassifier(configuration: MLModelConfiguration())
                
                
                /*guard let model = try? VNCoreMLModel(for: loadedModel) else {
                    fatalError("Failesd to load model as VNCoreMLModel")
                }*/
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
                
            } catch {
                print("Error loading model: \(error)")
                fatalError("e")
            }
        }*/
        
        func handlePrediction(prediction: String) {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .predictionDidUpdate, object: prediction)
            }
        }
        
        // Esegue l'inferenza ogni volta che viene catturato un frame
                func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
                    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
                    
                    // Converte il pixelBuffer in UIImage per la classificazione
                    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                    let uiImage = UIImage(ciImage: ciImage)

                    // Effettua la classificazione diretta
                    classifyImage(image: uiImage)
                }
        
        /*func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            
            if isShowingResult {
                return
            }
            
            guard let resizedImage = preprocessImage(sampleBuffer) else { return }
            
            //guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            guard let pixelBuffer = resizedImage.toCVPixelBuffer() else { return }
            let exifOrientation = exifOrientationFromDeviceOrientation()
            
            //saveImageFromBuffer(sampleBuffer)
            
            /*let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: [:])
            do {
                try imageRequestHandler.perform([self.request!])
            } catch {
                print(error)
            }*/
        }*/
        
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
    
    /*func toMLMultiArray(size: CGSize) -> MLMultiArray? {
            // 1. Ridimensiona l'immagine alla dimensione richiesta
            guard let resizedImage = self.resize(to: size),
                  let cgImage = resizedImage.cgImage else {
                print("Errore nel ridimensionamento dell'immagine")
                return nil
            }

            // 2. Ottieni le informazioni sul colore e sui dati dell'immagine
            let width = Int(size.width)
            let height = Int(size.height)
            let bytesPerPixel = 4 // RGBA = 4 byte
            let bytesPerRow = bytesPerPixel * width
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let rawData = UnsafeMutablePointer<UInt8>.allocate(capacity: height * width * bytesPerPixel)
            
            guard let context = CGContext(
                data: rawData,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ) else {
                print("Errore nella creazione del contesto bitmap")
                rawData.deallocate()
                return nil
            }
            
            // Disegna l'immagine nel contesto per ottenere i dati dei pixel
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            
            // 3. Crea un MLMultiArray con la forma richiesta
            guard let mlMultiArray = try? MLMultiArray(shape: [1, NSNumber(value: height), NSNumber(value: width)], dataType: .float32) else {
                print("Errore nella creazione di MLMultiArray")
                rawData.deallocate()
                return nil
            }
            
            // 4. Popola l'MLMultiArray con i valori dei pixel
            var pixelIndex = 0
            for row in 0..<height {
                for col in 0..<width {
                    let index = (row * width + col) * bytesPerPixel
                    let r = Float32(rawData[index]) / 255.0
                    let g = Float32(rawData[index + 1]) / 255.0
                    let b = Float32(rawData[index + 2]) / 255.0
                    
                    // Converti in scala di grigi o utilizza i valori RGB a seconda del modello
                    let grayscale = (r + g + b) / 3.0
                    
                    // Inserisci il valore nel MultiArray
                    mlMultiArray[[0, NSNumber(value: row), NSNumber(value: col)]] = NSNumber(value: grayscale)
                    
                    pixelIndex += 1
                }
            }
            
            // Dealloca i dati raw
            rawData.deallocate()
            
            return mlMultiArray
        }*/
    
    func resize(to size: CGSize) -> UIImage? {
            UIGraphicsBeginImageContextWithOptions(size, false, self.scale)
            self.draw(in: CGRect(origin: .zero, size: size))
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return resizedImage
        }
    
    // Estensione per ridimensionare un'immagine a una nuova dimensione
    /*func resize(to size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        draw(in: CGRect(origin: .zero, size: size))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage ?? self
    }*/
    
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

extension CVPixelBuffer {
    /// Converte il CVPixelBuffer in un MLMultiArray con la forma desiderata.
    func toMLMultiArray() -> MLMultiArray? {
        // Passo 1: Blocca la base address del buffer e crea un CIImage
        CVPixelBufferLockBaseAddress(self, .readOnly)
        guard let baseAddress = CVPixelBufferGetBaseAddress(self) else {
            print("Errore nel recuperare la base address del PixelBuffer")
            return nil
        }
        
        // Crea un CIImage dal PixelBuffer
        let ciImage = CIImage(cvPixelBuffer: self)

        // Passo 2: Creazione di un contesto Core Image e converti CIImage in CGImage
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            print("Errore nella conversione da CIImage a CGImage")
            CVPixelBufferUnlockBaseAddress(self, .readOnly)
            return nil
        }

        // Passo 3: Crea un array di pixel dal CGImage
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = cgImage.bytesPerRow
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.noneSkipLast.rawValue

        // Buffer per immagazzinare i dati dei pixel
        var rawData = [UInt8](repeating: 0, count: Int(height * bytesPerRow))
        guard let contextRef = CGContext(data: &rawData,
                                         width: width,
                                         height: height,
                                         bitsPerComponent: 8,
                                         bytesPerRow: bytesPerRow,
                                         space: colorSpace,
                                         bitmapInfo: bitmapInfo) else {
            print("Errore nella creazione del contesto bitmap")
            CVPixelBufferUnlockBaseAddress(self, .readOnly)
            return nil
        }

        // Disegna l'immagine nel contesto per ottenere i dati dei pixel
        contextRef.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Passo 4: Crea un MLMultiArray con la forma desiderata
        guard let mlMultiArray = try? MLMultiArray(shape: [1, NSNumber(value: height), NSNumber(value: width)], dataType: .float32) else {
            print("Errore nella creazione di MLMultiArray")
            CVPixelBufferUnlockBaseAddress(self, .readOnly)
            return nil
        }

        // Passo 5: Riempire l'MLMultiArray con i dati dei pixel
        var pixelIndex = 0
        for row in 0..<height {
            for col in 0..<width {
                let index = (row * bytesPerRow) + (col * 4) // 4 valori per RGBA
                let r = Float32(rawData[index]) / 255.0
                let g = Float32(rawData[index+1]) / 255.0
                let b = Float32(rawData[index+2]) / 255.0

                // Calcola la scala di grigi o usa un solo canale se il modello richiede un array unidimensionale
                let grayscale = (r + g + b) / 3.0
                
                // Inserisci il valore nel MultiArray
                mlMultiArray[[0, NSNumber(value: row), NSNumber(value: col)]] = NSNumber(value: grayscale)

                pixelIndex += 1
            }
        }

        // Rilascia il buffer del PixelBuffer
        CVPixelBufferUnlockBaseAddress(self, .readOnly)

        return mlMultiArray
    }
}
