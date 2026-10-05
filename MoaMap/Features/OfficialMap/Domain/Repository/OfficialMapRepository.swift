@MainActor
protocol OfficialMapRepository {
    func fetchOfficialMaps() async throws -> [OfficialMap]
}
