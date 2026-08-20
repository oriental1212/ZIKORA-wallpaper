import CryptoKit
import Foundation
import ImageIO
import Testing

struct ImageFixtureTests {
    private struct Manifest: Decodable {
        let fixtures: [Fixture]
        let license: String
    }

    private struct Fixture: Decodable {
        let name: String
        let file: String
        let declaredMIMEType: String
        let expected: String
    }

    @Test("Fixture manifest is licensed and references bundled files")
    func fixtureManifest() throws {
        let manifest = try loadManifest()

        #expect(manifest.license.contains("Generated in-repository"))
        #expect(manifest.fixtures.count == 5)
        for fixture in manifest.fixtures {
            #expect(!fixture.name.isEmpty)
            #expect(!fixture.declaredMIMEType.isEmpty)
            _ = try fixtureURL(named: fixture.file)
        }
    }

    @Test("Valid, corrupt, and pseudo-MIME image fixtures are distinguishable")
    func imageDecoding() throws {
        let validURL = try fixtureURL(named: "valid-small.png")
        let corruptURL = try fixtureURL(named: "corrupt-image.png")
        let fakeURL = try fixtureURL(named: "html-as-image.jpg")

        let validSource = try #require(CGImageSourceCreateWithURL(validURL as CFURL, nil))
        let corruptSource = try #require(CGImageSourceCreateWithURL(corruptURL as CFURL, nil))
        let fakeSource = try #require(CGImageSourceCreateWithURL(fakeURL as CFURL, nil))

        #expect(CGImageSourceGetCount(validSource) == 1)
        #expect(CGImageSourceCreateImageAtIndex(validSource, 0, nil) != nil)
        #expect(CGImageSourceGetCount(corruptSource) == 0)
        #expect(CGImageSourceGetCount(fakeSource) == 0)
    }

    @Test("Duplicate logical responses use identical content bytes")
    func duplicateContent() throws {
        let manifest = try loadManifest()
        let duplicates = manifest.fixtures.filter { $0.name.hasPrefix("duplicate-content-") }
        #expect(duplicates.count == 2)

        let hashes = try duplicates.map { fixture in
            let data = try Data(contentsOf: fixtureURL(named: fixture.file))
            return SHA256.hash(data: data)
        }
        #expect(hashes[0] == hashes[1])
    }

    private func loadManifest() throws -> Manifest {
        let url = try fixtureURL(named: "manifest.json")
        return try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: url))
    }

    private func fixtureURL(named fileName: String) throws -> URL {
        let name = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        let extensionName = URL(fileURLWithPath: fileName).pathExtension
        return try #require(Bundle(for: FixtureBundleToken.self).url(
            forResource: name,
            withExtension: extensionName
        ))
    }
}

private final class FixtureBundleToken {}
