import Foundation

/// SDK 콜백은 조립 지점에서 주입한다. Domain과 UI에는 SDK 타입을 노출하지 않는다.
@MainActor
final class KakaoAuthClient {
    typealias Completion = @Sendable (Result<String, any Error>) -> Void
    typealias LoginRequest = (@escaping Completion) -> Void

    private let isTalkAvailable: () -> Bool
    private let talkLogin: LoginRequest
    private let accountLogin: LoginRequest

    init(isTalkAvailable: @escaping () -> Bool, talkLogin: @escaping LoginRequest, accountLogin: @escaping LoginRequest) {
        self.isTalkAvailable = isTalkAvailable
        self.talkLogin = talkLogin
        self.accountLogin = accountLogin
    }

    func login() async throws -> String {
        try Task.checkCancellation()
        if isTalkAvailable() {
            do {
                return try await request(talkLogin)
            } catch is CancellationError {
                throw CancellationError()
            } catch LoginError.cancelled {
                throw LoginError.cancelled
            } catch {
                try Task.checkCancellation()
            }
        }
        return try await request(accountLogin)
    }

    private func request(_ start: LoginRequest) async throws -> String {
        let pending = KakaoLoginContinuation()
        let token = try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                guard pending.install(continuation) else { return }
                start { pending.finish($0) }
            }
        } onCancel: {
            pending.finish(.failure(CancellationError()))
        }
        try Task.checkCancellation()
        guard !token.isEmpty else { throw LoginError.invalidResponse }
        return token
    }
}

/// 취소와 SDK 콜백이 다른 스레드에서 도착해도 continuation은 한 번만 완료한다.
private nonisolated final class KakaoLoginContinuation: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<String, any Error>?
    private var result: Result<String, any Error>?

    func install(_ continuation: CheckedContinuation<String, any Error>) -> Bool {
        lock.lock()
        if let result {
            lock.unlock()
            continuation.resume(with: result)
            return false
        }
        self.continuation = continuation
        lock.unlock()
        return true
    }

    func finish(_ result: Result<String, any Error>) {
        lock.lock()
        guard self.result == nil else { lock.unlock(); return }
        self.result = result
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(with: result)
    }
}
