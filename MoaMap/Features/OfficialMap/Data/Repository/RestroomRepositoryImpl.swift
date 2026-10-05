import Foundation

@MainActor
final class RestroomRepositoryImpl: RestroomRepository {
    private static let path = ["api", "v1", "maps", "official", "restrooms"]

    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func fetchRestrooms(in bounds: ViewportBounds) async throws -> RestroomMarkers {
        let request = APIRequest(path: Self.path, queryItems: [
            URLQueryItem(name: "swLat", value: String(bounds.south)),
            URLQueryItem(name: "swLng", value: String(bounds.west)),
            URLQueryItem(name: "neLat", value: String(bounds.north)),
            URLQueryItem(name: "neLng", value: String(bounds.east))
        ])
        return try await client.send(request, as: RestroomListResponse.self).toDomain()
    }

    func fetchRestroom(id: Int64) async throws -> RestroomDetail {
        let request = APIRequest(path: Self.path + [String(id)])
        return try await client.send(request, as: RestroomDetailResponse.self).toDomain(id: id)
    }
}
