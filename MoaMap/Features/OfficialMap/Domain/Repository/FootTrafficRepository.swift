@MainActor
protocol FootTrafficRepository {
    /// 지역 목록과 실시간 혼잡도를 합쳐 돌려준다.
    func fetchDensityAreas() async throws -> [DensityArea]
}
