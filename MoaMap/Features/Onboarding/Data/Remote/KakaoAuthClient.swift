import Foundation

/// SDK 콜백은 조립 지점에서 주입한다. Domain과 UI에는 SDK 타입을 노출하지 않는다.
@MainActor
final class KakaoAuthClient {
    typealias Completion = @Sendable (Result<String, any Error>) -> Void
    typealias LoginRequest = (@escaping Completion) -> Void
    typealias UnlinkCompletion = @Sendable (Result<Void, any Error>) -> Void
    typealias UnlinkRequest = (@escaping UnlinkCompletion) -> Void

    private let isTalkAvailable: () -> Bool
    private let talkLogin: LoginRequest
    private let accountLogin: LoginRequest
    private let unlinkRequest: UnlinkRequest

    init(isTalkAvailable: @escaping () -> Bool, talkLogin: @escaping LoginRequest, accountLogin: @escaping LoginRequest,
         unlink: @escaping UnlinkRequest = { $0(.success(())) }) {
        self.isTalkAvailable = isTalkAvailable
        self.talkLogin = talkLogin
        self.accountLogin = accountLogin
        self.unlinkRequest = unlink
    }

    func login() async throws -> String {
        try Task.checkCancellation()
        if isTalkAvailable() {
            do {
                return try await token(talkLogin)
            } catch is CancellationError {
                throw CancellationError()
            } catch LoginError.cancelled {
                throw LoginError.cancelled
            } catch {
                try Task.checkCancellation()
            }
        }
        return try await token(accountLogin)
    }

    /// 이 앱과 카카오 계정의 연결을 끊는다. 이미 끊겼으면 성공으로 본다. 실패로 알리면 탈퇴를 영영 못 한다.
    func unlink() async throws {
        do {
            try await request(unlinkRequest)
        } catch KakaoUnlinkError.alreadyUnlinked {
            try Task.checkCancellation()
        }
    }

    private func token(_ start: LoginRequest) async throws -> String {
        let token = try await request(start)
        guard !token.isEmpty else { throw LoginError.invalidResponse }
        return token
    }

    private func request<Value: Sendable>(
        _ start: (@escaping @Sendable (Result<Value, any Error>) -> Void) -> Void
    ) async throws -> Value {
        let pending = KakaoContinuation<Value>()
        let value = try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                guard pending.install(continuation) else { return }
                start { pending.finish($0) }
            }
        } onCancel: {
            pending.finish(.failure(CancellationError()))
        }
        try Task.checkCancellation()
        return value
    }
}

/// 끊을 연결이 이미 없다는 카카오 오류. SDK 오류는 조립 지점에서 이 값으로 옮긴다.
nonisolated enum KakaoUnlinkError: Error, Equatable, Sendable {
    case alreadyUnlinked
}

/// 취소와 SDK 콜백이 다른 스레드에서 도착해도 continuation은 한 번만 완료한다.
private nonisolated final class KakaoContinuation<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, any Error>?
    private var result: Result<Value, any Error>?

    func install(_ continuation: CheckedContinuation<Value, any Error>) -> Bool {
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

    func finish(_ result: Result<Value, any Error>) {
        lock.lock()
        guard self.result == nil else { lock.unlock(); return }
        self.result = result
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(with: result)
    }
}
