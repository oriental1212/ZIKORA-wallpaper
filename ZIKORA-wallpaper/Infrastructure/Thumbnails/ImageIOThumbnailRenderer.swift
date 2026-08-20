import CoreGraphics
import Foundation
import ImageIO

struct ImageIOThumbnailRenderer: ThumbnailRendering, Sendable {
    func render(sourceURL: URL, destinationURL: URL, maxPixelSize: Int) async throws {
        try Task.checkCancellation()
        guard sourceURL.isFileURL,
              FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw AppFailure(code: .fileOperationFailed)
        }
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(
                  source,
                  0,
                  [
                      kCGImageSourceCreateThumbnailFromImageAlways: true,
                      kCGImageSourceCreateThumbnailWithTransform: true,
                      kCGImageSourceThumbnailMaxPixelSize: max(1, maxPixelSize),
                  ] as CFDictionary
              ),
              let destination = CGImageDestinationCreateWithURL(
                  destinationURL as CFURL,
                  "public.png" as CFString,
                  1,
                  nil
              ) else {
            throw AppFailure(code: .unsupportedImage, recoveryAction: .editSource)
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw AppFailure(code: .fileOperationFailed)
        }
        try Task.checkCancellation()
    }
}
