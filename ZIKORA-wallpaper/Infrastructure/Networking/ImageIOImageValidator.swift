import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Validates image bytes from their contents, not from a filename or URL.
struct ImageIOImageValidator: ImageValidating, Sendable {
    func validate(fileAt url: URL, declaredMIMEType: String?) async throws -> ValidatedImage {
        guard url.isFileURL,
              FileManager.default.fileExists(atPath: url.path),
              let mimeType = Self.normalizedMIMEType(declaredMIMEType),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 0,
              let actualTypeReference = CGImageSourceGetType(source),
              let actualIdentifier = actualTypeReference as String?,
              let actualType = UTType(actualIdentifier),
              Self.supportedMIMETypes.contains(mimeType),
              Self.mimeTypes(for: actualType).contains(mimeType),
              Self.magicBytesMatch(url: url, actualType: actualType),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw AppFailure(code: .unsupportedImage, recoveryAction: .editSource)
        }

        guard image.width > 0, image.height > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let pixelWidth = Self.pixelDimension(properties[kCGImagePropertyPixelWidth]),
              let pixelHeight = Self.pixelDimension(properties[kCGImagePropertyPixelHeight]),
              pixelWidth > 0, pixelHeight > 0 else {
            throw AppFailure(code: .unsupportedImage, recoveryAction: .editSource)
        }

        return ValidatedImage(
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            formatIdentifier: actualIdentifier
        )
    }

    private static let supportedMIMETypes: Set<String> = [
        "image/jpeg", "image/png", "image/heic", "image/heif", "image/webp"
    ]

    private static func normalizedMIMEType(_ value: String?) -> String? {
        guard let value else { return nil }
        return value.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: true)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func mimeTypes(for type: UTType) -> Set<String> {
        switch type.identifier {
        case UTType.jpeg.identifier:
            ["image/jpeg"]
        case UTType.png.identifier:
            ["image/png"]
        case UTType.heic.identifier:
            ["image/heic", "image/heif"]
        case UTType.heif.identifier:
            ["image/heif", "image/heic"]
        case UTType.webP.identifier:
            ["image/webp"]
        default:
            []
        }
    }

    private static func magicBytesMatch(url: URL, actualType: UTType) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url),
              let data = try? handle.read(upToCount: 16) else {
            return false
        }
        try? handle.close()

        let bytes = [UInt8](data)
        switch actualType.identifier {
        case UTType.jpeg.identifier:
            return bytes.starts(with: [0xFF, 0xD8, 0xFF])
        case UTType.png.identifier:
            return bytes.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        case UTType.heic.identifier, UTType.heif.identifier:
            guard bytes.count >= 12,
                  Array(bytes[4..<8]) == Array("ftyp".utf8) else { return false }
            let brand = String(bytes: bytes[8..<12], encoding: .ascii) ?? ""
            return ["heic", "heix", "hevc", "hevx", "mif1", "msf1"].contains(brand)
        case UTType.webP.identifier:
            return bytes.count >= 12
                && Array(bytes[0..<4]) == Array("RIFF".utf8)
                && Array(bytes[8..<12]) == Array("WEBP".utf8)
        default:
            return false
        }
    }

    private static func pixelDimension(_ value: Any?) -> Int? {
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let value = value as? Int {
            return value
        }
        return nil
    }
}
