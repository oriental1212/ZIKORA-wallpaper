import AppKit
import Foundation

nonisolated protocol URLOpening: Sendable {
    func open(_ url: URL) async -> Bool
}

struct NSWorkspaceURLOpener: URLOpening {
    func open(_ url: URL) async -> Bool {
        await MainActor.run { NSWorkspace.shared.open(url) }
    }
}

nonisolated enum FinderDirectoryError: Error, Equatable, Sendable {
    case invalidManagedPath
    case directoryUnavailable
    case fileMissing
    case openFailed
}

struct FinderCacheDirectoryService: Sendable {
    let rootURL: URL
    private let opener: any URLOpening
    private let fileManager: FileManager

    init(
        rootURL: URL,
        opener: any URLOpening = NSWorkspaceURLOpener(),
        fileManager: FileManager = .default
    ) {
        self.rootURL = rootURL.standardizedFileURL
        self.opener = opener
        self.fileManager = fileManager
    }

    func openDirectory() async throws -> URL {
        try ensureRootDirectory()
        guard await opener.open(rootURL) else { throw FinderDirectoryError.openFailed }
        return rootURL
    }

    func reveal(relativePath: ManagedRelativePath) async throws -> URL {
        try ensureRootDirectory()
        let url = rootURL.appendingPathComponent(relativePath.rawValue).standardizedFileURL
        guard Self.isInside(url: url, root: rootURL) else {
            throw FinderDirectoryError.invalidManagedPath
        }
        guard fileManager.fileExists(atPath: url.path) else {
            throw FinderDirectoryError.fileMissing
        }
        guard await opener.open(url) else { throw FinderDirectoryError.openFailed }
        return url
    }

    private func ensureRootDirectory() throws {
        if fileManager.fileExists(atPath: rootURL.path) {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: rootURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                throw FinderDirectoryError.directoryUnavailable
            }
            return
        }
        do {
            try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        } catch {
            throw FinderDirectoryError.directoryUnavailable
        }
    }

    static func isInside(url: URL, root: URL) -> Bool {
        let rootPath = root.standardizedFileURL.path
        let urlPath = url.standardizedFileURL.path
        return urlPath == rootPath || urlPath.hasPrefix(rootPath + "/")
    }
}
