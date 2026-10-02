import Foundation

@MainActor
final class PersonalMapRepositoryImpl: PersonalMapRepository {
    private static let myMapPageSize = 50
    /// 보통 첫 페이지에서 끝난다.
    private static let maxMyMapPages = 20

    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    /// 목록에서 들고 있던 값 대신 장소를 다시 읽는다. 지도 화면은 태그·사진 전체를 들고 있지 않다.
    /// 나만의 지도 id 는 기억해 두지 않는다. 다른 계정으로 다시 로그인하면 달라진다.
    func addPlace(placeID: Int64) async throws {
        let place = try await client.send(
            APIRequest(path: ["api", "v1", "places", String(placeID)]),
            as: PlaceDetailResponse.self
        )
        guard let mapID = try await findPersonalMapID() else { throw PersonalMapNotFoundError() }
        let body = try JSONEncoder().encode(try place.copyRequest(mapID: mapID))
        try await client.sendWithoutResponse(APIRequest(path: ["api", "v1", "places"], method: .post, jsonBody: body))
    }

    /// 나만의 지도는 프라이빗 목록에 섞여 내려와 `personal` 로만 가린다.
    private func findPersonalMapID() async throws -> Int64? {
        for page in 0..<Self.maxMyMapPages {
            let request = APIRequest(
                path: ["api", "v1", "maps", "me"],
                queryItems: [
                    URLQueryItem(name: "type", value: "PRIVATE"),
                    URLQueryItem(name: "page", value: String(page)),
                    URLQueryItem(name: "size", value: String(Self.myMapPageSize))
                ]
            )
            let response = try await client.send(request, as: PersonalMapPageResponse.self)
            let content = response.content ?? []
            if let map = content.first(where: { $0.personal == true }) { return map.id }
            if response.last ?? true || content.isEmpty { return nil }
        }
        return nil
    }
}

private nonisolated struct PersonalMapPageResponse: Decodable, Sendable {
    struct Map: Decodable, Sendable {
        let id: Int64
        let personal: Bool?
    }

    let content: [Map]?
    let last: Bool?
}
