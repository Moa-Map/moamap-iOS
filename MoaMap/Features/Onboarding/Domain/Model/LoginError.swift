nonisolated enum LoginError: Error, Equatable, Sendable {
    case cancelled
    case invalidResponse
    case notConfigured
}
