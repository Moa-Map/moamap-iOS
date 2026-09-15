import Foundation
@testable import MoaMap

nonisolated final class MemoryAuthTokenStore: AuthTokenStore, @unchecked Sendable {
    private let lock = NSLock()
    private var token: AuthToken?
    init(_ token: AuthToken? = nil) { self.token = token }
    func load() throws -> AuthToken? { lock.withLock { token } }
    func save(_ token: AuthToken) throws { lock.withLock { self.token = token } }
    func clear() throws { lock.withLock { token = nil } }
}

nonisolated final class MemoryCurrentUserStore: CurrentUserStore, @unchecked Sendable {
    private let lock = NSLock()
    private var userId: Int64?
    init(_ userId: Int64? = nil) { self.userId = userId }
    func load() throws -> Int64? { lock.withLock { userId } }
    func save(userId: Int64) throws { lock.withLock { self.userId = userId } }
    func clear() throws { lock.withLock { userId = nil } }
}

actor AsyncGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func open() {
        isOpen = true
        let pending = waiters
        waiters.removeAll()
        for waiter in pending { waiter.resume() }
    }
}

actor RefreshProbe {
    private(set) var receivedTokens: [String] = []
    let started = AsyncGate()
    let release: AsyncGate?
    let result: TokenRefreshResult
    init(_ result: TokenRefreshResult, release: AsyncGate? = nil) {
        self.result = result
        self.release = release
    }
    func refresh(refreshToken: String) async throws -> TokenRefreshResult {
        receivedTokens.append(refreshToken)
        await started.open()
        await release?.wait()
        return result
    }
}

// Release의 전체 모듈 최적화에서 protocol의 nonisolated가 actor 선언에 추론되지 않도록 분리한다.
extension RefreshProbe: TokenRefresher {}

actor AuthRequestRecorder {
    private(set) var headers: [String?] = []
    func record(_ request: URLRequest) { headers.append(request.value(forHTTPHeaderField: "Authorization")) }
}

nonisolated struct FailingCurrentUserStore: CurrentUserStore {
    struct StorageFailure: Error {}
    func load() throws -> Int64? { 42 }
    func save(userId: Int64) throws { throw StorageFailure() }
    func clear() throws { throw StorageFailure() }
}

nonisolated struct CancelledTokenRefresher: TokenRefresher {
    func refresh(refreshToken: String) async throws -> TokenRefreshResult { throw CancellationError() }
}
