import Foundation
import UIKit

enum ProfilePhotoProcessingError: Error {
    case invalidImage
    case encodingFailed
}

enum ProfilePhotoProcessor {
    static let maximumDimension: CGFloat = 1_024
    static let compressionQuality: CGFloat = 0.8

    static func process(_ data: Data) throws -> Data {
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else {
            throw ProfilePhotoProcessingError.invalidImage
        }

        let scale = min(1, maximumDimension / max(image.size.width, image.size.height))
        let targetSize = CGSize(
            width: max(1, (image.size.width * scale).rounded()),
            height: max(1, (image.size.height * scale).rounded())
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let normalized = UIGraphicsImageRenderer(size: targetSize, format: format).image { context in
            UIColor.systemBackground.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        guard let result = normalized.jpegData(compressionQuality: compressionQuality) else {
            throw ProfilePhotoProcessingError.encodingFailed
        }
        return result
    }
}
