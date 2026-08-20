import Foundation

/// Stores validated temporary images below one managed root using staging + atomic rename.
actor AtomicWallpaperFileStore: WallpaperFileStore {
    private let rootURL: URL
    private let clock: any Clock
    private let calendarProvider: any CalendarProviding
    private let uuidGenerator: any UUIDGenerating
    private let fileManager: FileManager

    init(
        rootURL: URL,
        clock: any Clock = SystemClock(),
        calendarProvider: any CalendarProviding = SystemCalendarProvider(),
        uuidGenerator: any UUIDGenerating = SystemUUIDGenerator(),
        fileManager: FileManager = .default
    ) throws {
        self.rootURL = rootURL.standardizedFileURL
        self.clock = clock
        self.calendarProvider = calendarProvider
        self.uuidGenerator = uuidGenerator
        self.fileManager = fileManager

        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: self.rootURL.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue else {
                throw AppFailure(code: .storageUnavailable)
            }
        } else {
            do {
                try fileManager.createDirectory(
                    at: self.rootURL,
                    withIntermediateDirectories: true
                )
            } catch {
                throw AppFailure(code: .storageUnavailable)
            }
        }
    }

    func commitTemporaryFile(at url: URL, preferredExtension: String) async throws -> String {
        try validateTemporarySource(url)
        defer { cleanup(url: url) }
        let fileExtension = try Self.normalizedExtension(preferredExtension)
        let now = await clock.now()
        let calendar = await calendarProvider.calendar()
        let day = LocalDay(containing: now, calendar: calendar)
        let identifier = await uuidGenerator.makeUUID().uuidString.lowercased()
        let relativePath = "\(day.rawValue)/\(identifier).\(fileExtension)"
        guard let managedPath = ManagedRelativePath(rawValue: relativePath) else {
            throw AppFailure(code: .fileOperationFailed)
        }

        let dayURL = rootURL.appendingPathComponent(day.rawValue, isDirectory: true)
        let destinationURL = rootURL.appendingPathComponent(managedPath.rawValue)
        let stagingURL = dayURL.appendingPathComponent(".\(identifier).partial")
        guard isWithinRoot(dayURL), isWithinRoot(destinationURL), isWithinRoot(stagingURL) else {
            throw AppFailure(code: .fileOperationFailed)
        }

        do {
            try fileManager.createDirectory(at: dayURL, withIntermediateDirectories: true)
            guard !fileManager.fileExists(atPath: destinationURL.path) else {
                throw AppFailure(code: .storageUnavailable)
            }
            try copyToStaging(from: url, to: stagingURL)
            try fileManager.moveItem(at: stagingURL, to: destinationURL)
            try? fileManager.removeItem(at: url)
            return managedPath.rawValue
        } catch is CancellationError {
            cleanup(url: stagingURL)
            throw AppFailure(code: .operationCancelled)
        } catch let error as AppFailure {
            cleanup(url: stagingURL)
            throw error
        } catch {
            cleanup(url: stagingURL)
            throw AppFailure(code: .fileOperationFailed)
        }
    }

    func remove(relativePath: String) async throws {
        guard let managedPath = ManagedRelativePath(rawValue: relativePath) else {
            throw AppFailure(code: .fileOperationFailed)
        }
        let fileURL = rootURL.appendingPathComponent(managedPath.rawValue)
        guard isWithinRoot(fileURL) else {
            throw AppFailure(code: .fileOperationFailed)
        }
        guard fileManager.fileExists(atPath: fileURL.path) else { return }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDirectory),
              !isDirectory.boolValue,
              fileURL.resolvingSymlinksInPath().standardizedFileURL.path
                  .hasPrefix(rootPrefix) else {
            throw AppFailure(code: .fileOperationFailed)
        }
        do {
            try fileManager.removeItem(at: fileURL)
        } catch {
            throw AppFailure(code: .fileOperationFailed)
        }
    }

    func statistics() async throws -> FileStoreStatistics {
        do {
            var count = 0
            var bytes: Int64 = 0
            guard let enumerator = fileManager.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey],
                options: [.skipsPackageDescendants]
            ) else {
                return FileStoreStatistics(fileCount: 0, byteCount: 0)
            }

            for case let fileURL as URL in enumerator.allObjects {
                let values = try fileURL.resourceValues(
                    forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
                )
                guard values.isRegularFile == true,
                      values.isSymbolicLink != true,
                      isWithinRoot(fileURL),
                      let fileSize = values.fileSize else { continue }
                count += 1
                bytes += Int64(fileSize)
            }
            return FileStoreStatistics(fileCount: count, byteCount: bytes)
        } catch {
            throw AppFailure(code: .fileOperationFailed)
        }
    }

    private func validateTemporarySource(_ url: URL) throws {
        guard url.isFileURL,
              fileManager.fileExists(atPath: url.path) else {
            throw AppFailure(code: .fileOperationFailed)
        }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw AppFailure(code: .fileOperationFailed)
        }
        guard !isWithinRoot(url) else {
            throw AppFailure(code: .fileOperationFailed)
        }
    }

    private func copyToStaging(from sourceURL: URL, to stagingURL: URL) throws {
        do {
            FileManager.default.createFile(atPath: stagingURL.path, contents: nil)
            let input = try FileHandle(forReadingFrom: sourceURL)
            let output = try FileHandle(forWritingTo: stagingURL)
            defer {
                try? input.close()
                try? output.close()
            }
            while let data = try input.read(upToCount: 1024 * 1024), !data.isEmpty {
                try Task.checkCancellation()
                try output.write(contentsOf: data)
            }
            try output.synchronize()
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as AppFailure {
            throw error
        } catch {
            throw AppFailure(code: .fileOperationFailed)
        }
    }

    private func isWithinRoot(_ url: URL) -> Bool {
        let resolved = url.resolvingSymlinksInPath().standardizedFileURL.path
        return resolved == rootURL.resolvingSymlinksInPath().standardizedFileURL.path
            || resolved.hasPrefix(rootPrefix)
    }

    private var rootPrefix: String {
        let resolved = rootURL.resolvingSymlinksInPath().standardizedFileURL.path
        return resolved.hasSuffix("/") ? resolved : resolved + "/"
    }

    private func cleanup(url: URL) {
        try? fileManager.removeItem(at: url)
    }

    private nonisolated static func normalizedExtension(_ value: String) throws -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty,
              normalized.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else {
            throw AppFailure(code: .fileOperationFailed)
        }
        return normalized
    }
}
