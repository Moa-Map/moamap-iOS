import Foundation

@MainActor
final class MapActivityRepositoryImpl: MapActivityRepository {
    private static let pageSize = 100

    private let client: APIClient
    private let timeZone: TimeZone

    init(client: APIClient, timeZone: TimeZone) {
        self.client = client
        self.timeZone = timeZone
    }

    func fetchActivities(mapID: Int64) async throws -> [MapActivity] {
        let request = APIRequest(
            path: ["api", "v1", "places", "activities"],
            queryItems: [
                URLQueryItem(name: "mapId", value: String(mapID)),
                URLQueryItem(name: "page", value: "0"),
                URLQueryItem(name: "size", value: String(Self.pageSize))
            ]
        )
        let response = try await client.send(request, as: PlaceActivityPageResponse.self)
        return (response.content ?? []).compactMap { $0.toDomain(timeZone: timeZone) }
    }
}

@MainActor
final class PendingPlaceRepositoryImpl: PendingPlaceRepository {
    private static let pageSize = 100
    private static let maxPages = 20

    private let client: APIClient
    private let timeZone: TimeZone

    init(client: APIClient, timeZone: TimeZone) {
        self.client = client
        self.timeZone = timeZone
    }

    func fetchPendingPlaces(mapID: Int64) async throws -> [PendingPlace] {
        var places: [PendingPlace] = []
        for page in 0..<Self.maxPages {
            let request = APIRequest(
                path: ["api", "v1", "places", "pending"],
                queryItems: [
                    URLQueryItem(name: "mapId", value: String(mapID)),
                    URLQueryItem(name: "page", value: String(page)),
                    URLQueryItem(name: "size", value: String(Self.pageSize))
                ]
            )
            let response = try await client.send(request, as: PendingPlacePageResponse.self)
            let content = response.content ?? []
            places += content.map { $0.toDomain(timeZone: timeZone) }
            if response.last ?? true || content.isEmpty { break }
        }
        return places
    }

    func approve(placeID: Int64) async throws {
        try await client.sendWithoutResponse(APIRequest(path: ["api", "v1", "places", String(placeID), "approve"], method: .patch))
    }

    func reject(placeID: Int64) async throws {
        try await client.sendWithoutResponse(APIRequest(path: ["api", "v1", "places", String(placeID), "reject"], method: .patch))
    }
}
