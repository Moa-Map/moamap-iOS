@MainActor
protocol ReportRepository {
    /// 내 것·중복·볼 수 없는 대상은 서버가 거절한다. 그 코드는 `NetworkError.server` 로 그대로 던진다.
    func report(_ target: ReportTarget, reason: ReportReason, detail: String?) async throws
}
