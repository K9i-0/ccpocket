import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Generates QR code images from strings using CoreImage.
final class QRCodeGenerator {
    private let context = CIContext()

    /// Generate a QR code NSImage from the given string.
    func generate(from string: String, size: CGFloat = 200) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let ciImage = filter.outputImage else { return nil }

        // Scale up from the small CIImage to desired size
        let scale = size / ciImage.extent.width
        let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
    }
}
