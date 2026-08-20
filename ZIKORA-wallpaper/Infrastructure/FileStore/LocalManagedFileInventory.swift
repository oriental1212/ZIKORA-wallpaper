import Foundation

actor LocalManagedFileInventory: ManagedFileInventoryProviding {
    private let rootURL: URL

    init(rootURL: URL) {
        self.rootURL = rootURL.standardizedFileURL
    }

    func inventory() async throws -> Set<ManagedRelativePath> {
        try Self.scan(rootURL: rootURL)
    }

    private nonisolated static func scan(rootURL: URL) throws -> Set<ManagedRelativePath> {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: rootURL.path, isDirectory: &isDirectory) else {
            return []
        }
        guard isDirectory.boolValue else {
            throw AppFailure(code: .fileOperationFailed)
        }

        let resolvedRoot = rootURL.resolvingSymlinksInPath().standardizedFileURL
        let rootPrefix = resolvedRoot.path.hasSuffix("/") ? resolvedRoot.path : resolvedRoot.path + "/"
        var enumerationError: Error?
        guard let enumerator = fileManager.enumerator(
            at: resolvedRoot,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsPackageDescendants],
            errorHandler: { _, error in
                enumerationError = error
                return false
            }
        ) else {
            throw AppFailure(code: .fileOperationFailed)
        }

        var paths: Set<ManagedRelativePath> = []
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else {
                continue
            }

            let resolvedFile = fileURL.resolvingSymlinksInPath().standardizedFileURL
            guard resolvedFile.path.hasPrefix(rootPrefix) else {
                continue
            }
            let relativeValue = String(resolvedFile.path.dropFirst(rootPrefix.count))
            if let relativePath = ManagedRelativePath(rawValue: relativeValue) {
                paths.insert(relativePath)
            }
        }

        if enumerationError != nil {
            throw AppFailure(code: .fileOperationFailed)
        }
        return paths
    }
}
