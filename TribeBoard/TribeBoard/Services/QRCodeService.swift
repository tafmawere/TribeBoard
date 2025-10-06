import SwiftUI
import CoreImage.CIFilterBuiltins

/// Service for generating QR codes
class QRCodeService {
    
    /// Generate a QR code image from text
    /// - Parameter text: The text to encode in the QR code
    /// - Returns: SwiftUI Image or nil if generation fails
    func generateQRCode(from text: String) -> Image? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        filter.message = Data(text.utf8)
        
        if let outputImage = filter.outputImage {
            // Scale up the QR code for better quality
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)
            
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                let uiImage = UIImage(cgImage: cgImage)
                return Image(uiImage: uiImage)
            }
        }
        
        return nil
    }
}