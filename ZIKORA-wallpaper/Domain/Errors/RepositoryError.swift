import Foundation

nonisolated enum RepositoryEntity: String, Codable, Sendable {
    case source
    case schedule
    case wallpaper
    case dailyFetchRecord
    case settings
}

nonisolated enum RepositoryOperation: String, Codable, Sendable {
    case fetch
    case save
    case delete
    case transaction
}

nonisolated enum RepositoryError: Error, Equatable, Sendable {
    case notFound(entity: RepositoryEntity)
    case duplicateContentHash
    case duplicateTaskKey
    case invalidPersistedValue(entity: RepositoryEntity, field: String)
    case persistenceFailed(entity: RepositoryEntity, operation: RepositoryOperation)
}
