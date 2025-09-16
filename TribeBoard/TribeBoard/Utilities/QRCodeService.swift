import UIKit
import CoreImage
import AVFoundation
import Vision

/// Service for QR code generation and scanning functionality
class QRCodeService: NSObject {
    
    // MARK: - Properties
    
    private let context = CIContext()
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var scanCompletion: ((Result<String, QRCodeError>) -> Void)?
    
    // MARK: - QR Code Generation
    
    /// Generates a QR code image from a string
    /// - Parameters:
    ///   - string: String to encode in QR code
    ///   - size: Size of the generated QR code image
    /// - Returns: UIImage containing the QR code, or nil if generation fails
    func generateQRCode(from string: String, size: CGSize = CGSize(width: 200, height: 200)) -> UIImage? {
        guard let data = string.data(using: .utf8) else {
            return nil
        }
        
        guard let qrFilter = CIFilter(name: "CIQRCodeGenerator") else {
            return nil
        }
        
        qrFilter.setValue(data, forKey: "inputMessage")
        qrFilter.setValue("M", forKey: "inputCorrectionLevel") // Medium error correction
        
        guard let qrImage = qrFilter.outputImage else {
            return nil
        }
        
        // Scale the QR code to desired size
        let scaleX = size.width / qrImage.extent.width
        let scaleY = size.height / qrImage.extent.height
        let scaledImage = qrImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    /// Generates a styled QR code with TribeBoard branding
    /// - Parameters:
    ///   - familyCode: Family code to encode
    ///   - size: Size of the generated QR code
    /// - Returns: Styled QR code image
    func generateStyledFamilyQRCode(familyCode: String, size: CGSize = CGSize(width: 300, height: 300)) -> UIImage? {
        // Create the base QR code
        guard let qrImage = generateQRCode(from: familyCode, size: size) else {
            return nil
        }
        
        // Create a styled version with border and label
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size.width + 40, height: size.height + 80))
        
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: renderer.format.bounds.size)
            
            // Background
            UIColor.systemBackground.setFill()
            context.fill(rect)
            
            // QR Code
            let qrRect = CGRect(x: 20, y: 20, width: size.width, height: size.height)
            qrImage.draw(in: qrRect)
            
            // Family code label
            let labelRect = CGRect(x: 20, y: size.height + 30, width: size.width, height: 30)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .medium),
                .foregroundColor: UIColor.label,
                .paragraphStyle: paragraphStyle
            ]
            
            familyCode.draw(in: labelRect, withAttributes: attributes)
        }
    }
    
    // MARK: - QR Code Scanning
    
    /// Scans QR code from an image
    /// - Parameter image: UIImage to scan for QR codes
    /// - Returns: String content of the first QR code found, or nil if none found
    func scanQRCode(from image: UIImage) -> String? {
        guard let cgImage = image.cgImage else { return nil }
        
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
            
            guard let results = request.results,
                  let firstResult = results.first,
                  let payload = firstResult.payloadStringValue else {
                return nil
            }
            
            return payload
        } catch {
            return nil
        }
    }
    
    /// Sets up camera session for live QR code scanning
    /// - Parameters:
    ///   - previewView: UIView to display camera preview
    ///   - completion: Completion handler called when QR code is detected
    /// - Throws: QRCodeError if camera setup fails
    func setupCameraSession(previewView: UIView, completion: @escaping (Result<String, QRCodeError>) -> Void) throws {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            throw QRCodeError.cameraPermissionDenied
        }
        
        captureSession = AVCaptureSession()
        guard let captureSession = captureSession else {
            throw QRCodeError.cameraSetupFailed
        }
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            throw QRCodeError.cameraNotAvailable
        }
        
        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            throw QRCodeError.cameraSetupFailed
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            throw QRCodeError.cameraSetupFailed
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            throw QRCodeError.cameraSetupFailed
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.frame = previewView.layer.bounds
        previewLayer?.videoGravity = .resizeAspectFill
        
        if let previewLayer = previewLayer {
            previewView.layer.addSublayer(previewLayer)
        }
        
        self.scanCompletion = completion
    }
    
    /// Starts the camera session for QR code scanning
    func startScanning() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    /// Stops the camera session
    func stopScanning() {
        captureSession?.stopRunning()
    }
    
    /// Requests camera permission
    /// - Parameter completion: Completion handler with permission result
    static func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        stopScanning()
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension QRCodeService: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        guard let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else {
            return
        }
        
        // Stop scanning after first successful read
        stopScanning()
        
        // Validate that this looks like a family code
        let validation = Validation.validateFamilyCode(stringValue)
        if validation.isValid {
            scanCompletion?(.success(stringValue))
        } else {
            scanCompletion?(.failure(.invalidQRCode))
        }
    }
}

// MARK: - Error Types

enum QRCodeError: LocalizedError {
    case generationFailed
    case cameraPermissionDenied
    case cameraNotAvailable
    case cameraSetupFailed
    case scanningFailed
    case invalidQRCode
    
    var errorDescription: String? {
        switch self {
        case .generationFailed:
            return "Failed to generate QR code"
        case .cameraPermissionDenied:
            return "Camera permission is required to scan QR codes"
        case .cameraNotAvailable:
            return "Camera is not available on this device"
        case .cameraSetupFailed:
            return "Failed to set up camera for scanning"
        case .scanningFailed:
            return "Failed to scan QR code"
        case .invalidQRCode:
            return "QR code does not contain a valid family code"
        }
    }
}