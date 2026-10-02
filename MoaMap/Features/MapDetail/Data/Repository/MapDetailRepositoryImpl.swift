import Foundation

@MainActor
final class MapDetailRepositoryImpl: MapDetailRepository {
    /// 응답 하나가 지나치게 커지지 않을 만큼. 서버 상한은 2000 이다.
    static let placePageSize = 1000
    /// 서버가 `last` 를 잘못 내려도 무한히 돌지 않게 하는 상한.
    static let maxPlacePages = 20

    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func fetchMapDetail(mapID: Int64) async throws -> MapDetail {
        let request = APIRequest(path: ["api", "v1", "maps", String(mapID)])
        let response = try await client.send(request, as: MapDetailResponse.self)
        return response.toDomain(ownerName: try await fetchOwnerName(response.ownerId))
    }

    func fetchPlaces(mapID: Int64) async throws -> [MapPlace] {
        var places: [MapPlace] = []
        for page in 0..<Self.maxPlacePages {
            let request = APIRequest(
                path: ["api", "v1", "places"],
                queryItems: [
                    URLQueryItem(name: "mapId", value: String(mapID)),
                    URLQueryItem(name: "page", value: String(page)),
                    URLQueryItem(name: "size", value: String(Self.placePageSize))
                ]
            )
            let response = try await client.send(request, as: PlacePageResponse.self)
            let content = response.content ?? []
            places += content.compactMap { $0.toDomain() }
            // 빈 페이지도 끝으로 본다. `last` 하나만 믿으면 루프가 끝나지 않을 수 있다.
            if response.last ?? true || content.isEmpty { break }
        }
        return places
    }

    func joinMap(mapID: Int64) async throws {
        let request = APIRequest(path: ["api", "v1", "maps", String(mapID), "join"], method: .post)
        try await client.sendWithoutResponse(request)
    }

    func leaveMap(mapID: Int64) async throws {
        let request = APIRequest(path: ["api", "v1", "maps", String(mapID), "members", "me"], method: .delete)
        try await client.sendWithoutResponse(request)
    }

    func deleteMap(mapID: Int64) async throws {
        let request = APIRequest(path: ["api", "v1", "maps", String(mapID)], method: .delete)
        try await client.sendWithoutResponse(request)
    }

    func setPlaceLiked(placeID: Int64, liked: Bool) async throws -> PlaceLike {
        let request = APIRequest(path: ["api", "v1", "places", String(placeID), "likes"], method: liked ? .post : .delete)
        let response = try await client.send(request, as: PlaceLikeResponse.self)
        return PlaceLike(liked: response.liked ?? liked, likeCount: response.likeCount ?? 0)
    }

    /// 곁들이는 정보라 실패를 삼킨다. 이름 한 줄 때문에 지도를 못 여는 게 더 나쁘다.
    private func fetchOwnerName(_ ownerID: Int64?) async throws -> String? {
        guard let ownerID, ownerID > 0 else { return nil }
        let request = APIRequest(
            path: ["api", "v1", "users", "profiles"],
            queryItems: [URLQueryItem(name: "ids", value: String(ownerID))]
        )
        do {
            let profiles = try await client.send(request, as: [UserProfileResponse].self)
            return profiles.first { $0.id == ownerID }?.nickname
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return nil
        }
    }
}
