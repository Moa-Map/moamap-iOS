import Foundation

@MainActor
protocol AppleAuthorizationSession: AnyObject {
    typealias Completion = @MainActor (Result<AppleLoginCredential, any Error>) -> Void
    func start(nonce: String, completion: @escaping Completion)
    func cancel()
}

@MainActor
final class AppleAuthClient {
    private let makeSession: () throws -> any AppleAuthorizationSession

    init(makeSession: @escaping () throws -> any AppleAuthorizationSession) {
        self.makeSession = makeSession
    }

    func login(nonce: String) async throws -> AppleLoginCredential {
        try Task.checkCancellation()
        let operation = AppleLoginOperation(session: try makeSession())
        let credential = try await withTaskCancellationHandler {
            try await operation.run(nonce: nonce)
        } onCancel: {
            Task { @MainActor in operation.cancel() }
        }
        try Task.checkCancellation()
        return credential
    }
}

/// 요청마다 별도 수명을 가진다. 이전 요청의 취소·중복 콜백은 새 요청에 접근할 수 없다.
@MainActor
private final class AppleLoginOperation {
    private let session: any AppleAuthorizationSession
    private var continuation: CheckedContinuation<AppleLoginCredential, any Error>?
    private var isFinished = false

    init(session: any AppleAuthorizationSession) { self.session = session }

    func run(nonce: String) async throws -> AppleLoginCredential {
        try Task.checkCancellation()
        return try await withCheckedThrowingContinuation { continuation in
            guard !isFinished else {
                continuation.resume(throwing: CancellationError())
                return
            }
            self.continuation = continuation
            session.start(nonce: nonce) { [weak self] in self?.finish($0) }
        }
    }

    func cancel() {
        guard !isFinished else { return }
        finish(.failure(CancellationError()))
        session.cancel()
    }

    private func finish(_ result: Result<AppleLoginCredential, any Error>) {
        guard !isFinished else { return }
        isFinished = true
        let pending = continuation
        continuation = nil
        pending?.resume(with: result)
    }
}
