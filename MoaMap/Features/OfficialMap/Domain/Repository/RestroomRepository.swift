@MainActor
protocol RestroomRepository {
    func fetchRestrooms(in bounds: ViewportBounds) async throws -> RestroomMarkers
    func fetchRestroom(id: Int64) async throws -> RestroomDetail
}
