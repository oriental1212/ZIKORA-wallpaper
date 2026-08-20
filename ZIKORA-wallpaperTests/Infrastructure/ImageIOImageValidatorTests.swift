import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import ZIKORA_wallpaper

@MainActor
struct ImageIOImageValidatorTests {
    private let validator = ImageIOImageValidator()

    @Test("PNG validation returns decoded dimensions and content UTI")
    func validatesPNG() async throws {
        let result = try await validator.validate(
            fileAt: try fixtureURL(named: "valid-small.png"),
            declaredMIMEType: "image/png; charset=binary"
        )

        #expect(result.pixelWidth == 2)
        #expect(result.pixelHeight == 2)
        #expect(result.formatIdentifier == "public.png")
    }

    @Test("JPEG, HEIC, and WebP are validated from encoded bytes")
    func validatesSupportedEncodedFormats() async throws {
        let source = try fixtureURL(named: "valid-small.png")
        guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            Issue.record("The PNG fixture could not be decoded for format generation")
            return
        }

        let formats: [(UTType, String, String)] = [
            (.jpeg, "jpg", "image/jpeg"),
            (.heic, "heic", "image/heic")
        ]
        for (type, fileExtension, mimeType) in formats {
            let fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("validator-\(UUID().uuidString).\(fileExtension)")
            defer { try? FileManager.default.removeItem(at: fileURL) }
            guard let destination = CGImageDestinationCreateWithURL(
                fileURL as CFURL,
                type.identifier as CFString,
                1,
                nil
            ) else {
                Issue.record("ImageIO cannot encode \(type.identifier) on this SDK")
                continue
            }
            CGImageDestinationAddImage(destination, image, nil)
            #expect(CGImageDestinationFinalize(destination))

            let result = try await validator.validate(fileAt: fileURL, declaredMIMEType: mimeType)
            #expect(result.pixelWidth == 2)
            #expect(result.pixelHeight == 2)
            #expect(result.formatIdentifier == type.identifier)
        }

        let webPURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("validator-\(UUID().uuidString).webp")
        defer { try? FileManager.default.removeItem(at: webPURL) }
        let webPBytes = try #require(Data(base64Encoded:
            "UklGRhoAAABXRUJQVlA4TA0AAAAvAAAAEAcQERGIiP4HAA=="
        ))
        try webPBytes.write(to: webPURL, options: .atomic)
        let webPResult = try await validator.validate(fileAt: webPURL, declaredMIMEType: "image/webp")
        #expect(webPResult.pixelWidth == 1)
        #expect(webPResult.pixelHeight == 1)
        #expect(webPResult.formatIdentifier == UTType.webP.identifier)
    }

    @Test("Declared MIME and extension cannot disguise the actual bytes")
    func rejectsMIMEAndExtensionMismatch() async throws {
        let source = try fixtureURL(named: "valid-small.png")
        let disguised = FileManager.default.temporaryDirectory
            .appendingPathComponent("image.jpg")
        try FileManager.default.copyItem(at: source, to: disguised)
        defer { try? FileManager.default.removeItem(at: disguised) }

        await #expect(throws: AppFailure(code: .unsupportedImage)) {
            try await validator.validate(fileAt: disguised, declaredMIMEType: "image/jpeg")
        }
        await #expect(throws: AppFailure(code: .unsupportedImage)) {
            try await validator.validate(fileAt: source, declaredMIMEType: nil)
        }
    }

    @Test("HTML and corrupt payloads fail ImageIO and magic-byte validation")
    func rejectsInvalidPayloads() async throws {
        await #expect(throws: AppFailure(code: .unsupportedImage)) {
            try await validator.validate(
                fileAt: try fixtureURL(named: "html-as-image.jpg"),
                declaredMIMEType: "image/jpeg"
            )
        }
        await #expect(throws: AppFailure(code: .unsupportedImage)) {
            try await validator.validate(
                fileAt: try fixtureURL(named: "corrupt-image.png"),
                declaredMIMEType: "image/png"
            )
        }
    }

    @Test("Unsupported formats and non-files are rejected")
    func rejectsUnsupportedInput() async throws {
        let emptyFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("validator-empty-\(UUID().uuidString).png")
        try Data().write(to: emptyFile, options: .atomic)
        defer { try? FileManager.default.removeItem(at: emptyFile) }
        await #expect(throws: AppFailure(code: .unsupportedImage)) {
            try await validator.validate(fileAt: emptyFile, declaredMIMEType: "image/png")
        }
        await #expect(throws: AppFailure(code: .unsupportedImage)) {
            try await validator.validate(
                fileAt: try fixtureURL(named: "source/valid-small.ppm"),
                declaredMIMEType: "image/x-portable-pixmap"
            )
        }
        await #expect(throws: AppFailure(code: .unsupportedImage)) {
            try await validator.validate(
                fileAt: URL(string: "https://example.test/image.png")!,
                declaredMIMEType: "image/png"
            )
        }
    }

    private func fixtureURL(named fileName: String) throws -> URL {
        let fileURL = URL(fileURLWithPath: fileName)
        return try #require(Bundle(for: FixtureBundleToken.self).url(
            forResource: fileURL.deletingPathExtension().lastPathComponent,
            withExtension: fileURL.pathExtension
        ))
    }
}

private final class FixtureBundleToken {}
