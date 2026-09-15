/// 내비게이션이 수신하기 전에도 만료 신호 하나를 보관한다. 단일 소비자가 수신한다.
nonisolated final class SessionEvents: Sendable {
    let sessionExpired: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation

    init() {
        let pair = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        sessionExpired = pair.stream
        continuation = pair.continuation
    }

    func notifySessionExpired() { continuation.yield(()) }
    deinit { continuation.finish() }
}
